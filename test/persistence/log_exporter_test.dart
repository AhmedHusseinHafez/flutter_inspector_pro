import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:requests_inspector/requests_inspector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final controller = LogPersistenceController.instance;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('inspector_export_test');
  });

  tearDown(() async {
    await controller.resetForTesting();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('LogExporter.escapeCsvField', () {
    test('leaves plain values untouched', () {
      expect(LogExporter.escapeCsvField('GET'), 'GET');
      expect(
        LogExporter.escapeCsvField('https://api.example.com/users'),
        'https://api.example.com/users',
      );
    });

    test('quotes values containing a comma, quote or newline', () {
      expect(LogExporter.escapeCsvField('a,b'), '"a,b"');
      expect(LogExporter.escapeCsvField('say "hi"'), '"say ""hi"""');
      expect(LogExporter.escapeCsvField('line1\nline2'), '"line1\nline2"');
    });
  });

  group('LogExporter.buildCsv', () {
    test('writes the header even with no entries', () {
      final csv = LogExporter.buildCsv(const []);
      expect(csv.trim(), LogExporter.csvHeader.join(','));
    });

    test('writes one row per entry, in column order', () {
      final csv = LogExporter.buildCsv([
        PersistedLogEntry(
          type: PersistedLogType.http,
          time: DateTime.utc(2026, 9, 19, 10),
          name: 'USERS',
          method: 'GET',
          url: 'https://api.example.com/users?page=1',
          statusCode: 200,
          durationMs: 250,
          details: '{"ok":true}',
        ),
      ]);

      final rows = csv.trim().split('\n');
      expect(rows, hasLength(2));
      expect(
        rows.last,
        'HTTP,2026-09-19T10:00:00.000Z,USERS,GET,'
        'https://api.example.com/users?page=1,200,250,,,"{""ok"":true}"',
      );
    });

    test('renders missing values as empty columns', () {
      final csv = LogExporter.buildCsv([
        PersistedLogEntry(
          type: PersistedLogType.sse,
          time: DateTime.utc(2026, 9, 19, 10),
          name: 'DATA',
        ),
      ]);

      final columns = csv.trim().split('\n').last.split(',');
      expect(columns, hasLength(LogExporter.csvHeader.length));
      expect(columns.sublist(3).every((c) => c.isEmpty), isTrue);
    });
  });

  group('LogExporter.buildFileName', () {
    test('stamps the current time and uses the format extension', () {
      expect(
        LogExporter.buildFileName(
          LogExportFormat.csv,
          DateTime(2026, 9, 19, 14, 3, 2),
        ),
        'inspector_logs_2026-09-19_14-03-02.csv',
      );
      expect(
        LogExporter.buildFileName(
          LogExportFormat.json,
          DateTime(2026, 1, 2, 9, 8, 7),
        ),
        'inspector_logs_2026-01-02_09-08-07.json',
      );
    });
  });

  group('LogExporter.export', () {
    setUp(() => controller.init(
          const LogPersistenceConfig(
            askOnFirstOpen: false,
            defaultTypes: {PersistedLogType.http, PersistedLogType.files},
          ),
          directory: tempDir,
        ));

    void recordSample() {
      controller.recordRequest(
        RequestDetails(
          requestMethod: RequestMethod.POST,
          url: 'https://api.example.com/login',
          statusCode: 401,
          sentTime: DateTime(2026, 9, 19, 10),
        ),
      );
      controller.recordFileRequest(
        FileRequestDetails(
          url: 'https://cdn.example.com/a/logo.png?v=2',
          sentTime: DateTime(2026, 9, 19, 9),
          statusCode: 200,
          contentLength: 2048,
        ),
      );
    }

    test('exports every saved type, newest first', () async {
      recordSample();

      final result = await LogExporter.export(
        now: DateTime(2026, 9, 19, 12),
      );

      expect(result, isNotNull);
      expect(result!.entryCount, 2);
      expect(result.fileName, 'inspector_logs_2026-09-19_12-00-00.csv');
      expect(await result.file.exists(), isTrue);

      final rows = (await result.file.readAsString()).trim().split('\n');
      expect(rows.first, LogExporter.csvHeader.join(','));
      expect(rows[1], contains('api.example.com/login'));
      expect(rows[1], contains('401'));
      // The file entry is older, so it lands after the HTTP one.
      expect(rows[2], contains('logo.png'));
      expect(rows[2], contains('2048'));
    });

    test('can export a single type', () async {
      recordSample();

      final result = await LogExporter.export(
        types: const [PersistedLogType.files],
      );

      expect(result!.entryCount, 1);
      expect(await result.file.readAsString(), contains('logo.png'));
      expect(
        await result.file.readAsString(),
        isNot(contains('api.example.com/login')),
      );
    });

    test('exports valid JSON when asked for it', () async {
      recordSample();

      final result = await LogExporter.export(format: LogExportFormat.json);
      final decoded = await result!.file.readAsString();

      expect(result.format, LogExportFormat.json);
      expect(result.fileName, endsWith('.json'));
      expect(decoded, startsWith('['));
      expect(decoded, contains('"t":"http"'));
    });

    test('exports a header-only CSV when nothing was saved', () async {
      final result = await LogExporter.export();

      expect(result!.entryCount, 0);
      expect(
        (await result.file.readAsString()).trim(),
        LogExporter.csvHeader.join(','),
      );
    });
  });
}
