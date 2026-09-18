import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:requests_inspector/requests_inspector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirebaseMessagingInspector.attach', () {
    setUp(() {
      FirebaseMessagingInspector.reset();
      FirebaseMessagingLogController.clear();
    });

    tearDown(FirebaseMessagingInspector.reset);

    test('does nothing when disabled', () {
      expect(
        () => FirebaseMessagingInspector.attach(
          const FirebaseMessagingInspectorConfig(enabled: false),
        ),
        returnsNormally,
      );
      expect(FirebaseMessagingLogController.events.value, isEmpty);
    });

    // No Firebase app is initialized in this test environment (no
    // TestFirebaseCoreHostApi mock registered), which is exactly the
    // "Firebase not initialized yet" scenario the inspector needs to survive
    // without crashing the host app.
    test('does not throw when Firebase has not been initialized', () {
      expect(
        () => FirebaseMessagingInspector.attach(
          const FirebaseMessagingInspectorConfig(enabled: true),
        ),
        returnsNormally,
      );
    });

    test('is safe to call multiple times (no duplicate attachment crash)', () {
      const config = FirebaseMessagingInspectorConfig(enabled: true);
      expect(() {
        FirebaseMessagingInspector.attach(config);
        FirebaseMessagingInspector.attach(config);
        FirebaseMessagingInspector.attach(config);
      }, returnsNormally);
    });
  });

  group('FirebaseMessagingInspector.logBackgroundMessage', () {
    setUp(FirebaseMessagingLogController.clear);

    test('logs the message as an onBackgroundMessage event when enabled', () async {
      await FirebaseMessagingInspector.logBackgroundMessage(
        RemoteMessage(messageId: 'bg-1'),
        config: const FirebaseMessagingInspectorConfig(enabled: true),
      );

      final events = FirebaseMessagingLogController.events.value;
      expect(events.length, 1);
      expect(events.first.type, FirebaseMessagingEventType.onBackgroundMessage);
      expect(events.first.messageId, 'bg-1');
    });

    test('does nothing when disabled', () async {
      await FirebaseMessagingInspector.logBackgroundMessage(
        RemoteMessage(messageId: 'bg-2'),
        config: const FirebaseMessagingInspectorConfig(enabled: false),
      );

      expect(FirebaseMessagingLogController.events.value, isEmpty);
    });

    test('applies the given config\'s masking rules', () async {
      await FirebaseMessagingInspector.logBackgroundMessage(
        RemoteMessage(
          messageId: 'bg-3',
          data: const {'token': 'secret-value'},
        ),
        config: const FirebaseMessagingInspectorConfig(enabled: true),
      );

      final event = FirebaseMessagingLogController.events.value.single;
      expect(event.data!['token'], '***');
    });
  });

  group('Coexistence with app-registered listeners', () {
    // FirebaseMessaging.onMessage/onMessageOpenedApp are broadcast streams,
    // which is what lets this package's listener and an app's own listener
    // both receive every event without either one stealing it from the
    // other. This test documents/pins that underlying assumption using a
    // local broadcast stream, since the real FirebaseMessaging streams
    // require a platform channel this test environment doesn't provide.
    test('a broadcast stream delivers events to every listener', () async {
      final controller = StreamController<RemoteMessage>.broadcast();
      final inspectorReceived = <String?>[];
      final appReceived = <String?>[];

      controller.stream.listen((m) => inspectorReceived.add(m.messageId));
      controller.stream.listen((m) => appReceived.add(m.messageId));

      controller.add(RemoteMessage(messageId: 'shared-1'));
      await Future<void>.delayed(Duration.zero);

      expect(inspectorReceived, ['shared-1']);
      expect(appReceived, ['shared-1']);

      await controller.close();
    });
  });
}
