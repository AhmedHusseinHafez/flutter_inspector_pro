import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:requests_inspector/requests_inspector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final controller = LogPersistenceController.instance;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('inspector_logs_test');
  });

  tearDown(() async {
    await controller.resetForTesting();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  RequestDetails buildRequest({String url = 'https://api.example.com/users'}) =>
      RequestDetails(
        requestMethod: RequestMethod.GET,
        url: url,
        statusCode: 200,
        responseBody: const {'ok': true},
        sentTime: DateTime(2026, 9, 19, 10),
        receivedTime: DateTime(2026, 9, 19, 10, 0, 0, 250),
      );

  group('PersistedLogStats', () {
    test('summarises count and size for the switches', () {
      expect(PersistedLogStats.empty.summary, 'Nothing saved');
      expect(
        const PersistedLogStats(entryCount: 1, sizeBytes: 800).summary,
        '1 entry · 800 B',
      );
      expect(
        const PersistedLogStats(entryCount: 12, sizeBytes: 4300).summary,
        '12 entries · 4.2 KB',
      );
      expect(
        const PersistedLogStats(entryCount: 9000, sizeBytes: 3 * 1024 * 1024)
            .readableSize,
        '3.0 MB',
      );
    });
  });

  group('LogFileStore', () {
    test('reports the entry count and size of what it wrote', () async {
      final store = LogFileStore(tempDir);
      expect(
        (await store.stats(PersistedLogType.http)).summary,
        'Nothing saved',
      );

      await store.append(PersistedLogType.http, [
        PersistedLogEntry(
          type: PersistedLogType.http,
          time: DateTime(2026, 9, 19, 10),
          name: 'USERS',
        ).toJsonLine(),
      ]);

      final stats = await store.stats(PersistedLogType.http);
      expect(stats.entryCount, 1);
      expect(stats.sizeBytes, greaterThan(0));
      expect(stats.summary, startsWith('1 entry · '));
    });
  });

  group('LogPersistenceController', () {
    test('writes nothing while no type is enabled', () async {
      await controller.init(
        const LogPersistenceConfig(askOnFirstOpen: false),
        directory: tempDir,
      );

      controller.recordRequest(buildRequest());
      await controller.flush();

      expect(controller.isAnyTypeEnabled, isFalse);
      expect(await controller.readSavedEntries(), isEmpty);
    });

    test('persists only the enabled types', () async {
      await controller.init(
        const LogPersistenceConfig(
          askOnFirstOpen: false,
          defaultTypes: {PersistedLogType.http},
        ),
        directory: tempDir,
      );

      controller.recordRequest(buildRequest());
      controller.recordFileRequest(
        FileRequestDetails(
          url: 'https://cdn.example.com/logo.png',
          sentTime: DateTime(2026, 9, 19, 9),
          statusCode: 200,
          contentLength: 1024,
        ),
      );
      await controller.flush();

      final entries = await controller.readSavedEntries();
      expect(entries, hasLength(1));
      expect(entries.single.type, PersistedLogType.http);
      expect(entries.single.url, 'https://api.example.com/users');
      expect(entries.single.statusCode, 200);
      expect(entries.single.durationMs, 250);
    });

    test('passing defaultTypes counts as an answered prompt', () async {
      await controller.init(
        const LogPersistenceConfig(
          defaultTypes: {PersistedLogType.sse},
        ),
        directory: tempDir,
      );

      expect(controller.shouldPromptOnOpen, isFalse);
      expect(controller.isTypeEnabled(PersistedLogType.sse), isTrue);
    });

    test('prompts on first open, then remembers the answer', () async {
      await controller.init(
        const LogPersistenceConfig(),
        directory: tempDir,
      );
      expect(controller.shouldPromptOnOpen, isTrue);

      await controller.setEnabledTypes({PersistedLogType.firebaseMessaging});
      expect(controller.shouldPromptOnOpen, isFalse);

      // Simulate a fresh app launch against the same directory.
      await controller.resetForTesting();
      await controller.init(
        const LogPersistenceConfig(),
        directory: tempDir,
      );

      expect(controller.shouldPromptOnOpen, isFalse);
      expect(
        controller.enabledTypes.value,
        {PersistedLogType.firebaseMessaging},
      );
    });

    test('declining the prompt is remembered as "save nothing"', () async {
      await controller.init(
        const LogPersistenceConfig(),
        directory: tempDir,
      );
      await controller.declinePrompt();

      await controller.resetForTesting();
      await controller.init(
        const LogPersistenceConfig(),
        directory: tempDir,
      );

      expect(controller.shouldPromptOnOpen, isFalse);
      expect(controller.enabledTypes.value, isEmpty);
    });

    test('keeps entries recorded before init finished', () async {
      // Recorded while the directory is still being resolved.
      controller.recordRequest(buildRequest(url: 'https://api.example.com/a'));

      await controller.init(
        const LogPersistenceConfig(
          askOnFirstOpen: false,
          defaultTypes: {PersistedLogType.http},
        ),
        directory: tempDir,
      );
      await controller.flush();

      final entries = await controller.readSavedEntries();
      expect(entries.map((e) => e.url), contains('https://api.example.com/a'));
    });

    test('drops pre-init entries for types that end up disabled', () async {
      controller.recordRequest(buildRequest());

      await controller.init(
        const LogPersistenceConfig(
          askOnFirstOpen: false,
          defaultTypes: {PersistedLogType.sse},
        ),
        directory: tempDir,
      );
      await controller.flush();

      expect(await controller.readSavedEntries(), isEmpty);
    });

    test('trims each type to maxEntriesPerType', () async {
      await controller.init(
        const LogPersistenceConfig(
          askOnFirstOpen: false,
          defaultTypes: {PersistedLogType.http},
          maxEntriesPerType: 5,
        ),
        directory: tempDir,
      );

      for (var i = 0; i < 12; i++) {
        controller.recordRequest(
          RequestDetails(
            requestMethod: RequestMethod.GET,
            url: 'https://api.example.com/$i',
            sentTime: DateTime(2026, 9, 19, 10, i),
          ),
        );
      }
      await controller.flush();

      final entries = await controller.readSavedEntries();
      expect(entries, hasLength(5));
      // Newest kept, oldest dropped.
      expect(entries.first.url, 'https://api.example.com/11');
      expect(entries.last.url, 'https://api.example.com/7');
    });

    test('keeps every entry when maxEntriesPerType is unlimited', () async {
      await controller.init(
        const LogPersistenceConfig(
          askOnFirstOpen: false,
          defaultTypes: {PersistedLogType.http},
          maxEntriesPerType: LogPersistenceConfig.unlimited,
        ),
        directory: tempDir,
      );

      for (var i = 0; i < 12; i++) {
        controller.recordRequest(
          RequestDetails(
            requestMethod: RequestMethod.GET,
            url: 'https://api.example.com/$i',
            sentTime: DateTime(2026, 9, 19, 10, i),
          ),
        );
      }
      await controller.flush();

      expect(await controller.readSavedEntries(), hasLength(12));
    });

    test('attributes SSE lines to the connection they belong to', () async {
      await controller.init(
        const LogPersistenceConfig(
          askOnFirstOpen: false,
          defaultTypes: {PersistedLogType.sse},
        ),
        directory: tempDir,
      );

      controller.recordSseLine('CONNECTING -> https://sse.example.com/stream');
      controller.recordSseLine('DATA: {"tick":1}');
      controller.recordSseLine('[10:00:01.500] ERROR socket closed');
      await controller.flush();

      final entries = await controller.readSavedEntries();
      expect(entries, hasLength(3));
      expect(
        entries.every((e) => e.url == 'https://sse.example.com/stream'),
        isTrue,
      );
      final errorEntry = entries.firstWhere((e) => e.name == 'ERROR');
      expect(errorEntry.error, 'ERROR socket closed');
      // The stored line keeps no duplicate timestamp prefix.
      expect(errorEntry.details, 'ERROR socket closed');
    });

    test('omits bodies when includeBodies is false', () async {
      await controller.init(
        const LogPersistenceConfig(
          askOnFirstOpen: false,
          defaultTypes: {PersistedLogType.http},
          includeBodies: false,
        ),
        directory: tempDir,
      );

      controller.recordRequest(buildRequest());
      await controller.flush();

      final entry = (await controller.readSavedEntries()).single;
      expect(entry.details, isNull);
      expect(entry.url, isNotNull);
    });

    test('truncates oversized details', () async {
      await controller.init(
        const LogPersistenceConfig(
          askOnFirstOpen: false,
          defaultTypes: {PersistedLogType.http},
          maxDetailsLength: 40,
        ),
        directory: tempDir,
      );

      controller.recordRequest(
        RequestDetails(
          requestMethod: RequestMethod.POST,
          url: 'https://api.example.com/big',
          responseBody: {'payload': 'x' * 500},
        ),
      );
      await controller.flush();

      final entry = (await controller.readSavedEntries()).single;
      expect(entry.details, endsWith('…(truncated)'));
      expect(entry.details!.length, lessThan(80));
    });

    test('keeps details in full when maxDetailsLength is unlimited', () async {
      await controller.init(
        const LogPersistenceConfig(
          askOnFirstOpen: false,
          defaultTypes: {PersistedLogType.http},
          maxDetailsLength: LogPersistenceConfig.unlimited,
        ),
        directory: tempDir,
      );

      controller.recordRequest(
        RequestDetails(
          requestMethod: RequestMethod.POST,
          url: 'https://api.example.com/big',
          responseBody: {'payload': 'x' * 500},
        ),
      );
      await controller.flush();

      final entry = (await controller.readSavedEntries()).single;
      expect(entry.details, isNot(endsWith('…(truncated)')));
      expect(entry.details!.length, greaterThan(500));
    });

    test('clear deletes one type, or everything', () async {
      await controller.init(
        const LogPersistenceConfig(
          askOnFirstOpen: false,
          defaultTypes: {PersistedLogType.http, PersistedLogType.sse},
        ),
        directory: tempDir,
      );

      controller.recordRequest(buildRequest());
      controller.recordSseLine('CONNECTING -> https://sse.example.com/stream');
      await controller.flush();
      expect(await controller.readSavedEntries(), hasLength(2));

      await controller.clear(PersistedLogType.http);
      expect(
        (await controller.readSavedEntries()).map((e) => e.type),
        [PersistedLogType.sse],
      );

      await controller.clear();
      expect(await controller.readSavedEntries(), isEmpty);
    });

    test('stops buffering once init lands with the feature disabled', () async {
      controller.recordRequest(buildRequest());

      await controller.init(
        const LogPersistenceConfig(enabled: false),
        directory: tempDir,
      );

      // Anything recorded after init is dropped outright, not held in memory.
      controller.recordRequest(buildRequest());
      await controller.flush();

      expect(controller.isReady, isFalse);
      expect(tempDir.listSync(), isEmpty);
    });

    test('is inert when the feature is disabled', () async {
      await controller.init(
        const LogPersistenceConfig(
          enabled: false,
          defaultTypes: {PersistedLogType.http},
        ),
        directory: tempDir,
      );

      controller.recordRequest(buildRequest());
      await controller.flush();

      expect(controller.isFeatureEnabled, isFalse);
      expect(controller.shouldPromptOnOpen, isFalse);
      expect(controller.enabledTypes.value, isEmpty);
      expect(tempDir.listSync(), isEmpty);
    });

    test('skips a half-written trailing line instead of failing', () async {
      await controller.init(
        const LogPersistenceConfig(
          askOnFirstOpen: false,
          defaultTypes: {PersistedLogType.http},
        ),
        directory: tempDir,
      );

      final store = LogFileStore(tempDir);
      await store.append(PersistedLogType.http, [
        json.encode({
          't': 'http',
          'ts': DateTime(2026, 9, 19, 10).toIso8601String(),
          'name': 'USERS',
        }),
        '{"t":"http","ts":"2026-09-1', // killed mid-write
      ]);

      final entries = await controller.readSavedEntries();
      expect(entries, hasLength(1));
      expect(entries.single.name, 'USERS');
    });
  });
}
