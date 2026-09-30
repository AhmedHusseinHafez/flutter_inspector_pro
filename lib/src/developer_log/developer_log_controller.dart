import 'package:flutter/foundation.dart';

import '../persistence/log_persistence_controller.dart';
import 'developer_log_entry.dart';

/// A lightweight global log of the app's own custom log entries, kept separate
/// from [InspectorController]'s HTTP request list on purpose (same pattern as
/// [SseLogController]/[FirebaseMessagingLogController]) and merged back into
/// the Inspector's "All" timeline for display.
///
/// Apps normally write to it through [InspectorLogger] rather than directly.
class DeveloperLogController {
  DeveloperLogController._();

  static final ValueNotifier<List<DeveloperLogEntry>> _entries =
      ValueNotifier<List<DeveloperLogEntry>>([]);

  static const int _maxEntries = 500;

  static ValueListenable<List<DeveloperLogEntry>> get entries => _entries;

  static void log(DeveloperLogEntry entry) {
    LogPersistenceController.instance.recordDeveloperLog(entry);
    final updated = [entry, ..._entries.value];
    if (updated.length > _maxEntries) {
      updated.removeRange(_maxEntries, updated.length);
    }
    _entries.value = updated;
  }

  static void remove(DeveloperLogEntry entry) {
    final updated = [..._entries.value]..removeWhere((e) => e.id == entry.id);
    _entries.value = updated;
  }

  static void clear() => _entries.value = [];
}
