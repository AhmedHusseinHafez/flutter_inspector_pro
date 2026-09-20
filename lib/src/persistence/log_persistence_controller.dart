import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../file_request_details.dart';
import '../firebase_messaging/firebase_messaging_event.dart';
import '../request_details.dart';
import 'log_file_store.dart';
import 'log_persistence_config.dart';
import 'persisted_log_entry.dart';
import 'persisted_log_type.dart';

/// Writes selected log categories to disk so they survive app restarts, and
/// exposes which categories are switched on so the inspector UI can show a
/// switch per category.
///
/// The three moving parts:
///
/// * **Choice** - which [PersistedLogType]s to save. Stored in a small
///   `settings.json` next to the logs, so the answer to the first-open prompt
///   (or the switches) is remembered across launches without pulling in
///   `shared_preferences`.
/// * **Recording** - `record*` methods are called by the in-memory log sinks
///   ([InspectorController], `SseLogController`, ...). They never block the
///   caller: entries go into a small buffer that is flushed to disk on a timer.
///   Anything recorded before [init] finishes is held and then either written
///   or dropped, depending on the restored choice - so logs from app startup
///   aren't lost.
/// * **Retention** - each category's file is trimmed to
///   [LogPersistenceConfig.maxEntriesPerType] entries after a flush, so the
///   files can't grow without bound.
class LogPersistenceController {
  LogPersistenceController._();

  static final LogPersistenceController instance =
      LogPersistenceController._();

  /// Name of the directory created inside the app's support directory.
  static const String directoryName = 'requests_inspector_logs';

  static const Duration _flushInterval = Duration(seconds: 2);
  static const int _flushThreshold = 25;
  /// Cap on entries held while waiting for [init]. Bounded because an app that
  /// never wraps itself in `RequestsInspector` (using a log sink directly) never
  /// calls [init], so this buffer would otherwise grow forever.
  static const int _maxPreInitBuffer = 200;

  LogPersistenceConfig _config = const LogPersistenceConfig(enabled: false);
  LogFileStore? _store;

  /// Whether [init] has run to completion, whatever its outcome. Recording
  /// buffers until this flips, then starts honouring the resolved choice.
  bool _initialized = false;
  bool _choiceStored = false;
  Timer? _flushTimer;
  Future<void> _writeQueue = Future<void>.value();

  /// Entries waiting to be written, keyed by category.
  final Map<PersistedLogType, List<PersistedLogEntry>> _pending = {};

  /// Entries recorded before [init] resolved the stored choice.
  final List<PersistedLogEntry> _preInitBuffer = [];

  /// Known entry count per file, kept in memory so trimming doesn't have to
  /// re-read every file on every flush.
  final Map<PersistedLogType, int> _counts = {};

  /// URL of the SSE connection whose lines are currently being logged, so each
  /// persisted line can be attributed to a connection.
  String? _currentSseUrl;

  /// The categories currently being saved to disk. Listenable so the storage
  /// dialog and any app-side UI can react to changes.
  final ValueNotifier<Set<PersistedLogType>> enabledTypes =
      ValueNotifier<Set<PersistedLogType>>(const {});

  LogPersistenceConfig get config => _config;

  /// Whether disk logging is offered at all (see
  /// [LogPersistenceConfig.enabled]). When `false` the inspector hides its
  /// storage button and nothing is ever written.
  bool get isFeatureEnabled => _config.enabled;

  /// Whether the store is resolved and usable. `false` before [init] finishes,
  /// and on platforms where no app directory is available (e.g. web).
  bool get isReady => _initialized && _store != null;

  bool get isAnyTypeEnabled => enabledTypes.value.isNotEmpty;

  bool isTypeEnabled(PersistedLogType type) =>
      enabledTypes.value.contains(type);

  /// Whether the "save your logs to disk?" prompt still has to be shown.
  bool get shouldPromptOnOpen =>
      _config.enabled && _config.askOnFirstOpen && !_choiceStored;

  /// Where logs are written, for showing the path in the UI.
  String? get directoryPath => _store?.directory.path;

  /// Resolves the storage directory, restores the saved choice (falling back to
  /// [LogPersistenceConfig.defaultTypes]) and starts the flush timer.
  ///
  /// Safe to call more than once; later calls only update the config. Pass
  /// [directory] to bypass `path_provider` (used by the tests).
  Future<void> init(LogPersistenceConfig config, {Directory? directory}) async {
    _config = config;
    if (!config.enabled) {
      _initialized = true;
      _preInitBuffer.clear();
      await _setEnabledTypes(const {}, persist: false);
      return;
    }

    if (_store == null) {
      final resolved = directory ?? await _resolveDirectory();
      if (resolved == null) {
        // No writable directory (web, or a platform without path_provider
        // support): silently stay off rather than break the inspector.
        _initialized = true;
        _preInitBuffer.clear();
        return;
      }
      _store = LogFileStore(resolved);
    }

    final settings = await _store!.readSettings();
    _choiceStored = settings['chosen'] == true;

    final restored = <PersistedLogType>{};
    final storedTypes = settings['types'];
    if (_choiceStored && storedTypes is List) {
      for (final name in storedTypes) {
        final type = PersistedLogType.fromFileName('$name');
        if (type != null) restored.add(type);
      }
    } else if (config.defaultTypes.isNotEmpty) {
      restored.addAll(config.defaultTypes);
      // Explicit defaults are already a decision, so don't also ask.
      _choiceStored = true;
      await _persistChoice(restored);
    }

    _initialized = true;
    await _setEnabledTypes(restored, persist: false);
    await _loadCounts();
    _drainPreInitBuffer();
    _startFlushTimer();
  }

  /// Replaces the set of saved categories and remembers the choice. Files for
  /// categories that were switched off are left on disk (so they can still be
  /// exported); use [clear] to delete them.
  Future<void> setEnabledTypes(Set<PersistedLogType> types) async {
    _choiceStored = true;
    await _setEnabledTypes(types, persist: true);
  }

  Future<void> setTypeEnabled(PersistedLogType type, bool enabled) {
    final updated = {...enabledTypes.value};
    if (enabled) {
      updated.add(type);
    } else {
      updated.remove(type);
    }
    return setEnabledTypes(updated);
  }

  /// Records "asked and declined", so the prompt isn't shown again.
  Future<void> declinePrompt() => setEnabledTypes(const {});

  Future<void> _setEnabledTypes(
    Set<PersistedLogType> types, {
    required bool persist,
  }) async {
    final unmodifiable = Set<PersistedLogType>.unmodifiable(types);
    final changed = !setEquals(enabledTypes.value, unmodifiable);
    if (changed) enabledTypes.value = unmodifiable;
    // Drop buffered entries for categories that were just switched off.
    _pending.removeWhere((type, _) => !unmodifiable.contains(type));
    if (persist) await _persistChoice(unmodifiable);
    if (changed) await flush();
  }

  Future<void> _persistChoice(Set<PersistedLogType> types) async {
    final store = _store;
    if (store == null) return;
    await store.writeSettings(<String, dynamic>{
      'chosen': true,
      'types': types.map((t) => t.fileName).toList(growable: false),
    });
  }

  // ---------------------------------------------------------------- recording

  void recordRequest(RequestDetails request) {
    if (!_isRecording(PersistedLogType.http)) return;
    _add(PersistedLogEntry(
      type: PersistedLogType.http,
      time: request.sentTime,
      name: request.requestName,
      method: request.requestMethod.name,
      url: request.url,
      statusCode: request.statusCode,
      durationMs: request.receivedTime
          ?.difference(request.sentTime)
          .inMilliseconds,
      details: _detailsJson(<String, dynamic>{
        'headers': request.headers,
        'queryParameters': request.queryParameters,
        'requestBody': request.requestBody,
        'graphqlRequestVars': request.graphqlRequestVars,
        'responseBody': request.responseBody,
      }),
    ));
  }

  /// Logs one raw SSE line. [message] is the already-timestamped line as stored
  /// by `SseLogController`.
  void recordSseLine(String message) {
    final body = _stripLeadingTimestamp(message);

    // Tracked even while SSE saving is off, so switching it on mid-stream still
    // attributes the following lines to the right connection.
    final connectingMatch = _connectingRegex.firstMatch(body);
    if (connectingMatch != null) {
      _currentSseUrl = connectingMatch.group(1)!.trim();
    }

    if (!_isRecording(PersistedLogType.sse)) return;
    _add(PersistedLogEntry(
      type: PersistedLogType.sse,
      time: DateTime.now(),
      name: _sseEventName(body),
      url: _currentSseUrl,
      error: body.contains('ERROR') ? body : null,
      details: _truncate(body),
    ));
  }

  void recordFirebaseMessagingEvent(FirebaseMessagingEvent event) {
    if (!_isRecording(PersistedLogType.firebaseMessaging)) return;
    _add(PersistedLogEntry(
      type: PersistedLogType.firebaseMessaging,
      time: event.receivedAt,
      name: event.displayTitle,
      method: event.type.name,
      url: event.from,
      details: _detailsJson(<String, dynamic>{
        'messageId': event.messageId,
        'senderId': event.senderId,
        'messageType': event.messageType,
        'collapseKey': event.collapseKey,
        'ttl': event.ttl,
        'sentTime': event.sentTime?.toIso8601String(),
        'notificationTitle': event.notificationTitle,
        'notificationBody': event.notificationBody,
        'data': event.data,
      }),
    ));
  }

  void recordFileRequest(FileRequestDetails details) {
    if (!_isRecording(PersistedLogType.files)) return;
    _add(PersistedLogEntry(
      type: PersistedLogType.files,
      time: details.sentTime,
      name: _fileNameFromUrl(details.url),
      method: 'GET',
      url: details.url,
      statusCode: details.statusCode,
      durationMs:
          details.receivedTime?.difference(details.sentTime).inMilliseconds,
      sizeBytes: details.contentLength,
      error: details.error,
      details: _detailsJson(<String, dynamic>{
        'contentType': details.contentType,
      }),
    ));
  }

  bool _isRecording(PersistedLogType type) {
    // Before init resolves the config and the stored choice, there's no way to
    // know yet whether this category is wanted - buffer it and decide once
    // init lands, so traffic from app startup isn't lost.
    if (!_initialized) return true;
    if (!_config.enabled) return false;
    return enabledTypes.value.contains(type);
  }

  void _add(PersistedLogEntry entry) {
    if (!_initialized) {
      if (_preInitBuffer.length >= _maxPreInitBuffer) return;
      _preInitBuffer.add(entry);
      return;
    }
    // Initialized but with nowhere to write (unsupported platform).
    if (_store == null) return;
    final bucket = _pending.putIfAbsent(entry.type, () => []);
    bucket.add(entry);
    if (bucket.length >= _flushThreshold) flush();
  }

  void _drainPreInitBuffer() {
    if (_preInitBuffer.isEmpty) return;
    final buffered = List<PersistedLogEntry>.from(_preInitBuffer);
    _preInitBuffer.clear();
    for (final entry in buffered) {
      if (!enabledTypes.value.contains(entry.type)) continue;
      _pending.putIfAbsent(entry.type, () => []).add(entry);
    }
    if (_pending.isNotEmpty) flush();
  }

  // ------------------------------------------------------------------ writing

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) {
      if (_pending.isNotEmpty) flush();
    });
  }

  /// Writes everything buffered so far. Writes are chained so two flushes can
  /// never interleave on the same file.
  Future<void> flush() {
    final store = _store;
    if (store == null || _pending.isEmpty) return _writeQueue;

    final batch = <PersistedLogType, List<PersistedLogEntry>>{};
    _pending.forEach((type, entries) {
      if (entries.isNotEmpty) batch[type] = List.of(entries);
    });
    _pending.clear();

    _writeQueue = _writeQueue.then((_) async {
      for (final entry in batch.entries) {
        final type = entry.key;
        try {
          await store.append(
            type,
            entry.value.map((e) => e.toJsonLine()).toList(growable: false),
          );
          final count = (_counts[type] ?? 0) + entry.value.length;
          _counts[type] = count;
          if (count > _config.maxEntriesPerType) {
            final remaining =
                await store.trim(type, _config.maxEntriesPerType);
            if (remaining != null) _counts[type] = remaining;
          }
        } catch (error) {
          // Disk full, permissions, app sandboxed mid-write: logging must never
          // take the host app down with it.
          debugPrint('[RequestsInspector] failed to persist ${type.label} '
              'logs: $error');
        }
      }
    });
    return _writeQueue;
  }

  Future<void> _loadCounts() async {
    final store = _store;
    if (store == null) return;
    for (final type in PersistedLogType.values) {
      _counts[type] = (await store.stats(type)).entryCount;
    }
  }

  // ------------------------------------------------------------------ reading

  Future<Map<PersistedLogType, PersistedLogStats>> stats() async {
    final store = _store;
    if (store == null) {
      return {for (final t in PersistedLogType.values) t: PersistedLogStats.empty};
    }
    await flush();
    final result = <PersistedLogType, PersistedLogStats>{};
    for (final type in PersistedLogType.values) {
      result[type] = await store.stats(type);
    }
    return result;
  }

  /// Every saved entry, newest first. Pass [types] to read only some
  /// categories.
  Future<List<PersistedLogEntry>> readSavedEntries({
    Iterable<PersistedLogType>? types,
  }) async {
    final store = _store;
    if (store == null) return const [];
    await flush();
    return store.readAll(types ?? PersistedLogType.values);
  }

  /// Deletes one category's saved logs, or all of them when [type] is null.
  ///
  /// Chained onto the write queue so an append that was already in flight can't
  /// land after the delete and resurrect the file.
  Future<void> clear([PersistedLogType? type]) {
    final store = _store;
    if (store == null) return Future<void>.value();

    if (type == null) {
      _pending.clear();
    } else {
      _pending.remove(type);
    }

    _writeQueue = _writeQueue.then((_) async {
      try {
        if (type == null) {
          await store.clearAll();
          _counts.updateAll((_, __) => 0);
        } else {
          await store.clear(type);
          _counts[type] = 0;
        }
      } catch (error) {
        debugPrint('[RequestsInspector] failed to delete saved logs: $error');
      }
    });
    return _writeQueue;
  }

  /// Writes [contents] to `<log dir>/<fileName>` and returns the file, ready to
  /// be handed to the platform share sheet.
  Future<File?> writeExportFile(String fileName, String contents) {
    final store = _store;
    if (store == null) return Future<File?>.value();
    return store.writeExport(fileName, contents);
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pending.clear();
    _preInitBuffer.clear();
    _counts.clear();
    _currentSseUrl = null;
    _store = null;
    _initialized = false;
    _choiceStored = false;
    _config = const LogPersistenceConfig(enabled: false);
    enabledTypes.value = const {};
    await _writeQueue;
  }

  // ------------------------------------------------------------------ helpers

  static final RegExp _connectingRegex = RegExp(r'CONNECTING\s*->\s*(.+)$');
  static final RegExp _timestampRegex = RegExp(r'^\[\d{2}:\d{2}:\d{2}\.\d{3}\]\s*');

  Future<Directory?> _resolveDirectory() async {
    Directory base;
    try {
      base = await getApplicationSupportDirectory();
    } catch (_) {
      // Not every platform implements the support directory (and on web the
      // plugin is missing entirely); fall back once, then give up quietly.
      try {
        base = await getApplicationDocumentsDirectory();
      } catch (error) {
        debugPrint('[RequestsInspector] disk logging unavailable: $error');
        return null;
      }
    }
    return Directory('${base.path}/$directoryName');
  }

  String? _detailsJson(Map<String, dynamic> map) {
    if (!_config.includeBodies) return null;
    map.removeWhere((_, value) => value == null);
    if (map.isEmpty) return null;
    try {
      return _truncate(json.encode(map, toEncodable: (value) => '$value'));
    } catch (_) {
      return _truncate('$map');
    }
  }

  String? _truncate(String? value) {
    if (value == null) return null;
    final max = _config.maxDetailsLength;
    if (max <= 0 || value.length <= max) return value;
    return '${value.substring(0, max)}…(truncated)';
  }

  static String _stripLeadingTimestamp(String message) =>
      message.replaceFirst(_timestampRegex, '');

  static String _sseEventName(String body) {
    final firstToken = body.trim().split(RegExp(r'\s+')).first;
    final name = firstToken.replaceAll(RegExp(r'[:\-]+$'), '');
    if (name.isEmpty) return 'SSE';
    return name.length <= 24 ? name : name.substring(0, 24);
  }

  static String _fileNameFromUrl(String url) {
    final path = url.split('?').first;
    final name = path.split('/').last;
    return name.isEmpty ? url : name;
  }
}
