import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:requests_inspector/requests_inspector.dart';

FirebaseMessagingEvent _event(String messageId) =>
    FirebaseMessagingEvent.fromRemoteMessage(
      RemoteMessage(messageId: messageId),
      FirebaseMessagingEventType.onMessage,
    );

void main() {
  group('FirebaseMessagingLogController', () {
    setUp(FirebaseMessagingLogController.clear);

    test('Initial events should be empty', () {
      expect(FirebaseMessagingLogController.events.value, isEmpty);
    });

    test('Should log new events newest-first', () {
      FirebaseMessagingLogController.log(_event('1'));
      FirebaseMessagingLogController.log(_event('2'));

      final events = FirebaseMessagingLogController.events.value;
      expect(events.length, 2);
      expect(events.first.messageId, '2');
      expect(events.last.messageId, '1');
    });

    test('Should remove a specific event by id', () {
      final first = _event('1');
      final second = _event('2');
      FirebaseMessagingLogController.log(first);
      FirebaseMessagingLogController.log(second);

      FirebaseMessagingLogController.remove(first);

      final events = FirebaseMessagingLogController.events.value;
      expect(events.length, 1);
      expect(events.first.messageId, '2');
    });

    test('Should clear all events', () {
      FirebaseMessagingLogController.log(_event('1'));
      FirebaseMessagingLogController.clear();

      expect(FirebaseMessagingLogController.events.value, isEmpty);
    });

    test('Should trim events to max entries', () {
      for (var i = 0; i < 210; i++) {
        FirebaseMessagingLogController.log(_event('$i'));
      }

      final events = FirebaseMessagingLogController.events.value;
      expect(events.length, 200);
      // Newest-first: the most recently logged event is first, the oldest
      // kept event (after trimming the earliest 10) is last.
      expect(events.first.messageId, '209');
      expect(events.last.messageId, '10');
    });
  });
}
