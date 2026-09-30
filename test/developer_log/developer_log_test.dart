import 'package:flutter_test/flutter_test.dart';
import 'package:requests_inspector/requests_inspector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InspectorLogger', () {
    setUp(() {
      InspectorLogger.enabled = true;
      DeveloperLogController.clear();
    });

    test('logs entries newest-first with level, tag and data', () {
      InspectorLogger.info('first', tag: 'Auth');
      InspectorLogger.warning('second', data: {'a': 1});

      final entries = DeveloperLogController.entries.value;
      expect(entries.length, 2);
      expect(entries.first.message, 'second');
      expect(entries.first.level, DeveloperLogLevel.warning);
      expect(entries.first.data, {'a': 1});
      expect(entries.last.tag, 'Auth');
      expect(entries.last.level, DeveloperLogLevel.info);
    });

    test('error captures error and stack trace', () {
      final trace = StackTrace.current;
      InspectorLogger.error('boom', error: StateError('x'), stackTrace: trace);

      final entry = DeveloperLogController.entries.value.single;
      expect(entry.hasError, isTrue);
      expect(entry.error, isA<StateError>());
      expect(entry.stackTrace, trace);
    });

    test('is a no-op when disabled', () {
      InspectorLogger.enabled = false;
      InspectorLogger.debug('ignored');
      expect(DeveloperLogController.entries.value, isEmpty);
    });

    test('remove and clear', () {
      InspectorLogger.debug('a');
      InspectorLogger.debug('b');
      final first = DeveloperLogController.entries.value.last;

      DeveloperLogController.remove(first);
      expect(DeveloperLogController.entries.value.single.message, 'b');

      DeveloperLogController.clear();
      expect(DeveloperLogController.entries.value, isEmpty);
    });

    test('caps stored entries at 500', () {
      for (var i = 0; i < 510; i++) {
        InspectorLogger.debug('$i');
      }
      final entries = DeveloperLogController.entries.value;
      expect(entries.length, 500);
      expect(entries.first.message, '509');
    });

    test('ids are unique even for entries logged in the same instant', () {
      final time = DateTime(2026);
      final a = DeveloperLogEntry(message: 'a', time: time);
      final b = DeveloperLogEntry(message: 'b', time: time);
      expect(a.id, isNot(b.id));
    });
  });

  group('DeveloperLogEntry.matches', () {
    final entry = DeveloperLogEntry(message: 'Checkout Started', tag: 'Cart');

    test('matches message and tag case-insensitively', () {
      expect(entry.matches('checkout'), isTrue);
      expect(entry.matches('CART'), isTrue);
      expect(entry.matches(''), isTrue);
      expect(entry.matches('payment'), isFalse);
    });
  });

  group('InspectorController developer log selection', () {
    test('selecting a developer log clears other selections', () {
      final controller = InspectorController();
      controller.selectedRequest = RequestDetails(
        url: 'http://example.com',
        requestMethod: RequestMethod.GET,
      );

      final entry = DeveloperLogEntry(message: 'hi');
      controller.selectDeveloperLog(entry);

      expect(controller.selectedDeveloperLog, entry);
      expect(controller.selectedRequest, isNull);
      expect(controller.selectedTab, 1);

      controller.selectedRequest = null;
      expect(controller.selectedDeveloperLog, isNull);
    });

    test('developerLog item filter hides HTTP requests', () {
      final controller = InspectorController();
      controller.addNewRequest(RequestDetails(
        url: 'http://example.com',
        requestMethod: RequestMethod.GET,
      ));
      controller.setItemTypeFilter(ItemTypeFilter.developerLog);
      expect(controller.filteredRequestsList, isEmpty);
      controller.clearFilters();
    });
  });
}
