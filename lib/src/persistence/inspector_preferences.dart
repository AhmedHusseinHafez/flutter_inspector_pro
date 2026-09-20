import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Small file-backed store for inspector switches the user flips in the UI
/// and expects to still be there after a restart.
///
/// Deliberately separate from [LogPersistenceController]'s `settings.json`:
/// these preferences must work even when disk logging is switched off
/// entirely, and the two would otherwise clobber each other's file.
///
/// The one preference so far is the Firebase Messaging capture kill switch.
/// It has to survive a restart to be worth anything: the failure it exists
/// for (a plugin hook that interferes with cold-start notification handling)
/// only shows up when the app launches, long before anyone can open the
/// inspector and flip a runtime-only switch.
class InspectorPreferences {
  InspectorPreferences._();

  static final InspectorPreferences instance = InspectorPreferences._();

  static const String directoryName = 'requests_inspector_logs';
  static const String fileName = 'inspector_preferences.json';

  static const String _firebaseMessagingKey = 'firebaseMessagingEnabled';

  File? _file;
  Map<String, dynamic> _values = const {};
  Future<void>? _loading;

  /// Reads the preferences file once. Safe to call repeatedly - later calls
  /// await the first load instead of re-reading. Never throws: an unreadable
  /// or missing file just means "no stored choices".
  Future<void> load({Directory? directory}) {
    return _loading ??= _load(directory);
  }

  Future<void> _load(Directory? directory) async {
    final resolved = directory ?? await _resolveDirectory();
    if (resolved == null) return;
    try {
      if (!await resolved.exists()) await resolved.create(recursive: true);
      final file = File('${resolved.path}/$fileName');
      _file = file;
      if (!await file.exists()) return;
      final decoded = json.decode(await file.readAsString());
      if (decoded is Map<String, dynamic>) _values = decoded;
    } catch (_) {
      // Corrupt or unreadable file - fall back to config defaults rather
      // than taking the host app down over a debugging preference.
    }
  }

  /// The user's stored choice for Firebase Messaging capture, or `null` when
  /// they've never touched the switch (so the app's config value wins).
  bool? get firebaseMessagingEnabled {
    final value = _values[_firebaseMessagingKey];
    return value is bool ? value : null;
  }

  Future<void> setFirebaseMessagingEnabled(bool enabled) =>
      _write(_firebaseMessagingKey, enabled);

  /// Forgets the stored choice, so the app's config value applies again.
  Future<void> clearFirebaseMessagingEnabled() =>
      _write(_firebaseMessagingKey, null);

  Future<void> _write(String key, Object? value) async {
    await load();
    final updated = Map<String, dynamic>.from(_values);
    if (value == null) {
      updated.remove(key);
    } else {
      updated[key] = value;
    }
    _values = updated;

    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString(json.encode(updated), flush: true);
    } catch (_) {
      // Keep the in-memory value for this session even if the write failed.
    }
  }

  /// Resets in-memory state so a test can load a fresh directory.
  static void resetForTesting() {
    instance._file = null;
    instance._values = const {};
    instance._loading = null;
  }

  Future<Directory?> _resolveDirectory() async {
    Directory base;
    try {
      base = await getApplicationSupportDirectory();
    } catch (_) {
      try {
        base = await getApplicationDocumentsDirectory();
      } catch (_) {
        // No writable directory (web, or a platform without path_provider).
        return null;
      }
    }
    return Directory('${base.path}/$directoryName');
  }
}
