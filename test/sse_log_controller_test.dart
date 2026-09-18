import 'package:flutter_test/flutter_test.dart';
import 'package:requests_inspector/src/sse/sse_log_controller.dart';

void main() {
  group('SseLogController', () {
    setUp(SseLogController.clear);

    test('Initial logs should be empty', () {
      expect(SseLogController.logs.value, isEmpty);
    });

    test('Should append log entries with timestamp prefix', () {
      SseLogController.log('CONNECTING -> https://example.com');

      expect(SseLogController.logs.value.length, 1);
      expect(
        SseLogController.logs.value.first,
        startsWith('['),
      );
      expect(
        SseLogController.logs.value.first,
        contains('CONNECTING -> https://example.com'),
      );
    });

    test('Should clear all log entries', () {
      SseLogController.log('event 1');
      SseLogController.log('event 2');

      SseLogController.clear();

      expect(SseLogController.logs.value, isEmpty);
    });

    test('Should trim logs to max entries', () {
      for (var i = 0; i < 210; i++) {
        SseLogController.log('event $i');
      }

      expect(SseLogController.logs.value.length, 200);
      expect(
        SseLogController.logs.value.first,
        contains('event 10'),
      );
      expect(
        SseLogController.logs.value.last,
        contains('event 209'),
      );
    });
  });
}
