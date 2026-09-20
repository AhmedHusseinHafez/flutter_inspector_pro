import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:requests_inspector/requests_inspector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('inspector_prefs_test');
    InspectorPreferences.resetForTesting();
    FirebaseMessagingInspector.reset();
  });

  tearDown(() async {
    FirebaseMessagingInspector.reset();
    InspectorPreferences.resetForTesting();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('InspectorPreferences', () {
    test('reports no stored choice before anything is written', () async {
      await InspectorPreferences.instance.load(directory: tempDir);
      expect(InspectorPreferences.instance.firebaseMessagingEnabled, isNull);
    });

    test('remembers the choice across a fresh load (restart)', () async {
      await InspectorPreferences.instance.load(directory: tempDir);
      await InspectorPreferences.instance.setFirebaseMessagingEnabled(false);

      // Simulate the next app launch: brand new in-memory state, same dir.
      InspectorPreferences.resetForTesting();
      await InspectorPreferences.instance.load(directory: tempDir);

      expect(InspectorPreferences.instance.firebaseMessagingEnabled, isFalse);
    });

    test('clearing the choice falls back to the config value', () async {
      await InspectorPreferences.instance.load(directory: tempDir);
      await InspectorPreferences.instance.setFirebaseMessagingEnabled(false);
      await InspectorPreferences.instance.clearFirebaseMessagingEnabled();

      InspectorPreferences.resetForTesting();
      await InspectorPreferences.instance.load(directory: tempDir);

      expect(InspectorPreferences.instance.firebaseMessagingEnabled, isNull);
    });

    test('survives a corrupt preferences file', () async {
      await File('${tempDir.path}/${InspectorPreferences.fileName}')
          .writeAsString('{not valid json');

      await InspectorPreferences.instance.load(directory: tempDir);

      expect(InspectorPreferences.instance.firebaseMessagingEnabled, isNull);
    });
  });

  group('FirebaseMessagingInspector capture switch', () {
    test('is unavailable (hidden in the UI) when the app opted out', () {
      FirebaseMessagingInspector.attach(
        const FirebaseMessagingInspectorConfig(enabled: false),
      );
      expect(FirebaseMessagingInspector.isAvailable, isFalse);
      expect(FirebaseMessagingInspector.isCapturing.value, isFalse);
    });

    test('is available once the app opted in', () {
      FirebaseMessagingInspector.attach(
        const FirebaseMessagingInspectorConfig(enabled: true),
      );
      expect(FirebaseMessagingInspector.isAvailable, isTrue);
    });

    test('switching off detaches and persists the choice', () async {
      await InspectorPreferences.instance.load(directory: tempDir);
      FirebaseMessagingInspector.attach(
        const FirebaseMessagingInspectorConfig(enabled: true),
      );

      await FirebaseMessagingInspector.setEnabled(false);

      expect(FirebaseMessagingInspector.isCapturing.value, isFalse);
      expect(InspectorPreferences.instance.firebaseMessagingEnabled, isFalse);
    });

    test('a stored "off" keeps attach() from listening on the next launch',
        () async {
      await InspectorPreferences.instance.load(directory: tempDir);
      await InspectorPreferences.instance.setFirebaseMessagingEnabled(false);

      FirebaseMessagingInspector.attach(
        const FirebaseMessagingInspectorConfig(enabled: true),
      );
      // attach() resolves the stored choice asynchronously, before touching
      // anything on FirebaseMessaging.
      await Future<void>.delayed(Duration.zero);

      expect(FirebaseMessagingInspector.isCapturing.value, isFalse);
    });

    test('a switch flipped during startup is not undone by the stored read',
        () async {
      await InspectorPreferences.instance.load(directory: tempDir);
      // attach() reads the stored choice asynchronously; flipping the switch
      // before that read lands must win, not lose to it.
      FirebaseMessagingInspector.attach(
        const FirebaseMessagingInspectorConfig(enabled: true),
      );
      await FirebaseMessagingInspector.setEnabled(false);
      await Future<void>.delayed(Duration.zero);

      expect(FirebaseMessagingInspector.isCapturing.value, isFalse);
    });

    test('switching back on clears the kill switch', () async {
      await InspectorPreferences.instance.load(directory: tempDir);
      FirebaseMessagingInspector.attach(
        const FirebaseMessagingInspectorConfig(enabled: true),
      );

      await FirebaseMessagingInspector.setEnabled(false);
      await FirebaseMessagingInspector.setEnabled(true);

      expect(InspectorPreferences.instance.firebaseMessagingEnabled, isTrue);
      expect(FirebaseMessagingInspector.isCapturing.value, isTrue);
    });
  });
}
