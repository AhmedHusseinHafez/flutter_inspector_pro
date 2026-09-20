import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

import 'log_export_format.dart';
import 'log_persistence_controller.dart';
import 'persisted_log_entry.dart';
import 'persisted_log_type.dart';

/// The outcome of an export: what was written, where, and how much of it.
class LogExportResult {
  const LogExportResult({
    required this.file,
    required this.fileName,
    required this.format,
    required this.entryCount,
  });

  final File file;
  final String fileName;
  final LogExportFormat format;
  final int entryCount;
}

/// Turns the logs saved on disk into a single lightweight file and hands it to
/// the platform share sheet (email, Slack, Drive, AirDrop, Files - whatever the
/// user picks).
class LogExporter {
  LogExporter._();

  static const List<String> csvHeader = [
    'type',
    'timestamp',
    'name',
    'method',
    'url',
    'status_code',
    'duration_ms',
    'size_bytes',
    'error',
    'details',
  ];

  /// Builds a CSV document with one row per entry and [csvHeader] as its first
  /// row. Values are quoted only when they need to be (comma, quote, newline),
  /// which keeps the file small and diff-friendly.
  static String buildCsv(List<PersistedLogEntry> entries) {
    final buffer = StringBuffer()..writeln(csvHeader.join(','));
    for (final entry in entries) {
      buffer.writeln([
        entry.type.label,
        entry.time.toIso8601String(),
        entry.name,
        entry.method ?? '',
        entry.url ?? '',
        entry.statusCode?.toString() ?? '',
        entry.durationMs?.toString() ?? '',
        entry.sizeBytes?.toString() ?? '',
        entry.error ?? '',
        entry.details ?? '',
      ].map(escapeCsvField).join(','));
    }
    return buffer.toString();
  }

  static String buildJson(List<PersistedLogEntry> entries) =>
      json.encode(entries.map((e) => e.toMap()).toList(growable: false));

  /// Quotes a single CSV field per RFC 4180, doubling any embedded quotes.
  static String escapeCsvField(String value) {
    final needsQuotes = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  /// e.g. `inspector_logs_2026-09-19_14-03-22.csv`
  static String buildFileName(LogExportFormat format, DateTime now) {
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp = '${now.year}-${two(now.month)}-${two(now.day)}'
        '_${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
    return 'inspector_logs_$stamp.${format.extension}';
  }

  /// Reads the saved logs (optionally only [types]), writes them out in
  /// [format], and returns the file. Returns `null` when disk logging isn't
  /// available, or an empty result when nothing has been saved yet.
  static Future<LogExportResult?> export({
    LogExportFormat format = LogExportFormat.csv,
    Iterable<PersistedLogType>? types,
    DateTime? now,
  }) async {
    final controller = LogPersistenceController.instance;
    final entries = await controller.readSavedEntries(types: types);
    final contents =
        format == LogExportFormat.csv ? buildCsv(entries) : buildJson(entries);
    final fileName = buildFileName(format, now ?? DateTime.now());
    final file = await controller.writeExportFile(fileName, contents);
    if (file == null) return null;
    return LogExportResult(
      file: file,
      fileName: fileName,
      format: format,
      entryCount: entries.length,
    );
  }

  /// Exports and immediately opens the share sheet, with a subject line filled
  /// in so sending the file by email takes one tap.
  static Future<LogExportResult?> exportAndShare({
    LogExportFormat format = LogExportFormat.csv,
    Iterable<PersistedLogType>? types,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    final result = await export(format: format, types: types);
    if (result == null) return null;

    final exportSubject = subject ??
        'Inspector logs (${result.entryCount} '
            '${result.entryCount == 1 ? 'entry' : 'entries'})';

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(result.file.path, mimeType: result.format.mimeType)],
        fileNameOverrides: [result.fileName],
        subject: exportSubject,
        title: exportSubject,
        text: 'Saved network logs exported from the in-app inspector.',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    return result;
  }
}
