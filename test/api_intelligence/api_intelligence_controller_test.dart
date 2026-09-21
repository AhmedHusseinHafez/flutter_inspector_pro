import 'package:flutter_test/flutter_test.dart';
import 'package:requests_inspector/requests_inspector.dart';

class _FakeAiProvider implements ApiIntelligenceAiProvider {
  _FakeAiProvider({this.reportText, this.error});

  final String? reportText;
  final Object? error;

  @override
  Future<String> generateReport(Map<String, dynamic> sanitizedPayload) async {
    if (error != null) throw error!;
    return reportText ?? 'API INTELLIGENCE REPORT';
  }
}

void main() {
  final controller = ApiIntelligenceController.instance;

  tearDown(controller.resetForTesting);

  List<RequestDetails> sampleRequests() => [
        RequestDetails(
          requestMethod: RequestMethod.GET,
          url: 'https://api.example.com/users',
          statusCode: 200,
          responseBody: const {'ok': true},
          sentTime: DateTime(2026, 1, 1, 10),
          receivedTime: DateTime(2026, 1, 1, 10, 0, 0, 200),
        ),
      ];

  test('deterministic results are always present with no AI provider', () async {
    controller.aiProvider = null;
    await controller.analyze(sampleRequests());

    expect(controller.state, ApiIntelligenceState.completed);
    expect(controller.result, isNotNull);
    expect(controller.aiReport, isNull);
    expect(controller.hasAiProvider, isFalse);
  });

  test('AI provider result is stored alongside deterministic results',
      () async {
    controller.aiProvider = _FakeAiProvider(reportText: 'my ai report');
    await controller.analyze(sampleRequests());

    expect(controller.result, isNotNull);
    expect(controller.aiReport, 'my ai report');
    expect(controller.aiError, isNull);
  });

  test('AI failure never discards the deterministic results', () async {
    controller.aiProvider = _FakeAiProvider(error: Exception('boom'));
    await controller.analyze(sampleRequests());

    expect(controller.result, isNotNull);
    expect(controller.aiReport, isNull);
    expect(controller.aiError, contains('boom'));
  });

  test('a second concurrent analyze() call while running is ignored', () async {
    controller.aiProvider = _FakeAiProvider();
    final first = controller.analyze(sampleRequests());
    final second = controller.analyze(sampleRequests());
    await Future.wait([first, second]);

    expect(controller.state, ApiIntelligenceState.completed);
  });

  test('clear() resets state back to idle', () async {
    controller.aiProvider = null;
    await controller.analyze(sampleRequests());
    expect(controller.result, isNotNull);

    controller.clear();

    expect(controller.state, ApiIntelligenceState.idle);
    expect(controller.result, isNull);
  });
}
