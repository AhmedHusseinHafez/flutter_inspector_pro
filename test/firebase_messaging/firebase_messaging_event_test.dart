import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:requests_inspector/requests_inspector.dart';

void main() {
  group('FirebaseMessagingEvent.fromRemoteMessage', () {
    test('parses core message metadata', () {
      final sentTime = DateTime(2026, 1, 1, 12);
      final message = RemoteMessage(
        messageId: 'msg-1',
        senderId: 'sender-1',
        from: '123456/topic',
        sentTime: sentTime,
        ttl: 3600,
        collapseKey: 'chat',
        messageType: 'message',
        data: const {'orderId': '42'},
      );

      final event = FirebaseMessagingEvent.fromRemoteMessage(
        message,
        FirebaseMessagingEventType.onMessage,
      );

      expect(event.type, FirebaseMessagingEventType.onMessage);
      expect(event.messageId, 'msg-1');
      expect(event.senderId, 'sender-1');
      expect(event.from, '123456/topic');
      expect(event.sentTime, sentTime);
      expect(event.ttl, 3600);
      expect(event.collapseKey, 'chat');
      expect(event.messageType, 'message');
      expect(event.data, {'orderId': '42'});
    });

    test('handles null/missing optional fields gracefully', () {
      final message = RemoteMessage();

      final event = FirebaseMessagingEvent.fromRemoteMessage(
        message,
        FirebaseMessagingEventType.onMessage,
      );

      expect(event.messageId, isNull);
      expect(event.senderId, isNull);
      expect(event.from, isNull);
      expect(event.sentTime, isNull);
      expect(event.ttl, isNull);
      expect(event.collapseKey, isNull);
      expect(event.data, isNull);
      expect(event.notificationTitle, isNull);
      expect(event.notificationBody, isNull);
      expect(event.android, isNull);
      expect(event.apple, isNull);
      expect(event.hasNotification, isFalse);
      // Falls back to the event type label when there's nothing else to show.
      expect(event.displayTitle, 'onMessage');
    });

    test('parses notification, android and apple payloads', () {
      final message = RemoteMessage(
        messageId: 'msg-2',
        notification: const RemoteNotification(
          title: 'New message',
          body: 'You have a new message',
          android: AndroidNotification(
            channelId: 'chat_channel',
            imageUrl: 'https://example.com/pic.png',
          ),
          apple: AppleNotification(badge: '3', subtitle: 'From Alice'),
        ),
      );

      final event = FirebaseMessagingEvent.fromRemoteMessage(
        message,
        FirebaseMessagingEventType.onMessageOpenedApp,
      );

      expect(event.hasNotification, isTrue);
      expect(event.notificationTitle, 'New message');
      expect(event.notificationBody, 'You have a new message');
      expect(event.displayTitle, 'New message');
      expect(event.android, isNotNull);
      expect(event.android!['channelId'], 'chat_channel');
      expect(event.android!['imageUrl'], 'https://example.com/pic.png');
      expect(event.apple, isNotNull);
      expect(event.apple!['badge'], '3');
      expect(event.apple!['subtitle'], 'From Alice');
    });

    test('displayTitle falls back to messageId when no notification title', () {
      final message = RemoteMessage(messageId: 'msg-3');

      final event = FirebaseMessagingEvent.fromRemoteMessage(
        message,
        FirebaseMessagingEventType.onBackgroundMessage,
      );

      expect(event.displayTitle, 'msg-3');
    });

    test('masks default sensitive data keys', () {
      final message = RemoteMessage(
        data: const {
          'orderId': '42',
          'authToken': 'super-secret',
          'password': 'hunter2',
        },
      );

      final event = FirebaseMessagingEvent.fromRemoteMessage(
        message,
        FirebaseMessagingEventType.onMessage,
      );

      expect(event.data!['orderId'], '42');
      expect(event.data!['authToken'], '***');
      expect(event.data!['password'], '***');
    });

    test('masks a custom set of keys when provided', () {
      final message = RemoteMessage(
        data: const {'orderId': '42', 'internalRef': 'ref-1'},
      );

      final event = FirebaseMessagingEvent.fromRemoteMessage(
        message,
        FirebaseMessagingEventType.onMessage,
        maskedDataKeys: {'internalref'},
      );

      expect(event.data!['orderId'], '42');
      expect(event.data!['internalRef'], '***');
    });

    test('does not mask anything when maskedDataKeys is empty', () {
      final message = RemoteMessage(
        data: const {'authToken': 'super-secret'},
      );

      final event = FirebaseMessagingEvent.fromRemoteMessage(
        message,
        FirebaseMessagingEventType.onMessage,
        maskedDataKeys: const {},
      );

      expect(event.data!['authToken'], 'super-secret');
    });

    test('two events get distinct ids', () {
      final message = RemoteMessage(messageId: 'msg-4');

      final first = FirebaseMessagingEvent.fromRemoteMessage(
        message,
        FirebaseMessagingEventType.onMessage,
      );
      final second = FirebaseMessagingEvent.fromRemoteMessage(
        message,
        FirebaseMessagingEventType.onMessageOpenedApp,
      );

      expect(first.id, isNot(second.id));
    });
  });

  group('FirebaseMessagingEventType.label', () {
    test('matches the real FirebaseMessaging API names', () {
      expect(FirebaseMessagingEventType.onMessage.label, 'onMessage');
      expect(
        FirebaseMessagingEventType.onMessageOpenedApp.label,
        'onMessageOpenedApp',
      );
      expect(
        FirebaseMessagingEventType.onBackgroundMessage.label,
        'onBackgroundMessage',
      );
      expect(FirebaseMessagingEventType.initialMessage.label, 'initialMessage');
    });
  });
}
