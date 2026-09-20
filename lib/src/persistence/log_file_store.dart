import 'dart:convert';
import 'dart:io';

import 'persisted_log_entry.dart';
import 'persisted_log_type.dart';

/// Per-category disk statistics, shown in the "Save logs to disk" dialog so
/// there's some feedback that saving is actually happening (and how much space
/// it's taking).
class PersistedLogStats {
  const PersistedLogStats({required this.entryCount, required this.sizeBytes});

  final int entryCount;
  final int sizeBytes;

  static const empty = PersistedLogStats(entryCount: 0, sizeBytes: 0);

  /// e.g. `12 entries · 4.2 KB`
  String get summary {
    if (entryCount == 0) return 'Nothing saved';
    final entries = entryCount == 1 ? '1 entry' : '$entryCount entries';
    return '$entries · $readableSize';
  }

  String get readableSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// The file layer behind [LogPersistenceController]: one append-only
/// JSON-Lines file per [PersistedLogType], plus a small `settings.json`
/// holding which categories are switched on.
///
/// Kept free of `path_provider` (the directory is injected) so it can be
/// exercised in tests against a plain temp directory.
class LogFileStore {
  LogFileStore(this.directory);

  final Directory directory;

  static const String settingsFileName = 'settings.json';

  File fileFor(PersistedLogType type) =>
      File('${directory.path}/${type.fileName}.jsonl');

  File get settingsFile => File('${directory.path}/$settingsFileName');

  Future<void> ensureDirectory() async {
    if (!await directory.exists()) await directory.create(recursive: true);
  }

  /// Appends already-encoded JSON lines, creating the file if needed.
  Future<void> append(PersistedLogType type, List<String> lines) async {
    if (lines.isEmpty) return;
    await ensureDirectory();
    await fileFor(type).writeAsString(
      '${lines.join('\n')}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  Future<List<PersistedLogEntry>> read(PersistedLogType type) async {
    final file = fileFor(type);
    if (!await file.exists()) return const [];
    final lines = await file.readAsLines();
    final entries = <PersistedLogEntry>[];
    for (final line in lines) {
      final entry = PersistedLogEntry.tryParse(line);
      if (entry != null) entries.add(entry);
    }
    return entries;
  }

  /// Reads every enabled category and returns all entries sorted newest first,
  /// which is the order both exports use.
  Future<List<PersistedLogEntry>> readAll([
    Iterable<PersistedLogType> types = PersistedLogType.values,
  ]) async {
    final entries = <PersistedLogEntry>[];
    for (final type in types) {
      entries.addAll(await read(type));
    }
    entries.sort((a, b) => b.time.compareTo(a.time));
    return entries;
  }

  Future<PersistedLogStats> stats(PersistedLogType type) async {
    final file = fileFor(type);
    if (!await file.exists()) return PersistedLogStats.empty;
    final length = await file.length();
    final lines = await file.readAsLines();
    return PersistedLogStats(
      entryCount: lines.where((l) => l.trim().isNotEmpty).length,
      sizeBytes: length,
    );
  }

  /// Drops the oldest lines so at most [maxEntries] remain. Returns the number
  /// of entries left, or `null` when no rewrite was needed.
  Future<int?> trim(PersistedLogType type, int maxEntries) async {
    if (maxEntries <= 0) return null;
    final file = fileFor(type);
    if (!await file.exists()) return null;
    final lines =
        (await file.readAsLines()).where((l) => l.trim().isNotEmpty).toList();
    if (lines.length <= maxEntries) return lines.length;
    final kept = lines.sublist(lines.length - maxEntries);
    await file.writeAsString('${kept.join('\n')}\n', flush: true);
    return kept.length;
  }

  Future<void> clear(PersistedLogType type) async {
    final file = fileFor(type);
    if (await file.exists()) await file.delete();
  }

  Future<void> clearAll() async {
    for (final type in PersistedLogType.values) {
      await clear(type);
    }
  }

  Future<Map<String, dynamic>> readSettings() async {
    final file = settingsFile;
    if (!await file.exists()) return const {};
    try {
      final decoded = json.decode(await file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  Future<void> writeSettings(Map<String, dynamic> settings) async {
    await ensureDirectory();
    await settingsFile.writeAsString(json.encode(settings), flush: true);
  }

  /// Writes an export next to the logs and returns the file, so it can be
  /// handed straight to the platform share sheet.
  Future<File> writeExport(String fileName, String contents) async {
    await ensureDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(contents, flush: true);
    return file;
  }
}
