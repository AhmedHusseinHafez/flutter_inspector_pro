import 'package:flutter_test/flutter_test.dart';
import 'package:requests_inspector/requests_inspector.dart';

RequestDetails _req({
  RequestMethod method = RequestMethod.GET,
  String url = 'https://api.example.com/users',
  int statusCode = 200,
  dynamic responseBody,
  dynamic responseHeaders,
  dynamic requestBody,
  dynamic queryParameters,
  DateTime? sentTime,
  DateTime? receivedTime,
}) {
  final sent = sentTime ?? DateTime(2026, 1, 1, 10, 0, 0);
  return RequestDetails(
    requestMethod: method,
    url: url,
    statusCode: statusCode,
    responseBody: responseBody,
    responseHeaders: responseHeaders,
    requestBody: requestBody,
    queryParameters: queryParameters,
    sentTime: sent,
    receivedTime: receivedTime ?? sent.add(const Duration(milliseconds: 200)),
  );
}

void main() {
  group('ApiIntelligenceAnalyzer - basics', () {
    test('empty session produces no endpoints and no findings', () {
      final result = ApiIntelligenceAnalyzer.analyze(const []);
      expect(result.session.requestCount, 0);
      expect(result.session.uniqueEndpointCount, 0);
      expect(result.endpointMetrics, isEmpty);
      expect(result.findings, isEmpty);
    });

    test('single request never produces a performance finding', () {
      final result = ApiIntelligenceAnalyzer.analyze([
        _req(receivedTime: DateTime(2026, 1, 1, 10, 0, 5)), // 5s single call
      ]);
      final performanceFindings =
          result.findingsOf(ApiIntelligenceCategory.performance);
      expect(performanceFindings, isEmpty);
    });

    test('missing timing/headers/bodies does not throw and yields no bogus stats',
        () {
      final request = RequestDetails(
        requestMethod: RequestMethod.GET,
        url: 'https://api.example.com/ping',
        sentTime: DateTime(2026, 1, 1),
      );
      final result = ApiIntelligenceAnalyzer.analyze([request]);
      expect(result.endpointMetrics.single.latencyStats, isNull);
      expect(result.hasTimingPhaseData, isFalse);
    });

    test('a value that is not valid JSON structure is treated as an opaque body',
        () {
      final result = ApiIntelligenceAnalyzer.analyze([
        _req(responseBody: '<html>not json</html>'),
      ]);
      expect(result.endpointMetrics, hasLength(1));
    });
  });

  group('ApiIntelligenceAnalyzer - latency & percentiles', () {
    test('computes median/p75/p95/min/max from repeated calls', () {
      final durations = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000];
      final requests = [
        for (var i = 0; i < durations.length; i++)
          _req(
            sentTime: DateTime(2026, 1, 1, 10, i),
            receivedTime:
                DateTime(2026, 1, 1, 10, i).add(Duration(milliseconds: durations[i])),
          ),
      ];
      final result = ApiIntelligenceAnalyzer.analyze(requests);
      final stats = result.endpointMetrics.single.latencyStats!;
      expect(stats.sampleCount, 10);
      expect(stats.minMs, 100);
      expect(stats.maxMs, 1000);
      expect(stats.medianMs, closeTo(550, 0.01));
    });

    test('flags a high-priority performance finding for consistently slow endpoint',
        () {
      final requests = [
        for (var i = 0; i < 5; i++)
          _req(
            sentTime: DateTime(2026, 1, 1, 10, i),
            receivedTime:
                DateTime(2026, 1, 1, 10, i).add(const Duration(milliseconds: 3500)),
          ),
      ];
      final result = ApiIntelligenceAnalyzer.analyze(requests);
      final findings = result.findingsOf(ApiIntelligenceCategory.performance);
      expect(findings, isNotEmpty);
      expect(findings.first.severity,
          FindingSeverity.highPriorityInvestigation);
    });
  });

  group('ApiIntelligenceAnalyzer - duplicate detection', () {
    test('flags a potential redundant request for a repeated identical signature',
        () {
      final requests = [
        for (var i = 0; i < 4; i++)
          _req(
            url: 'https://api.example.com/profile',
            sentTime: DateTime(2026, 1, 1, 10, 0, i),
            receivedTime: DateTime(2026, 1, 1, 10, 0, i, 200),
            responseBody: const {'ok': true},
          ),
      ];
      final result = ApiIntelligenceAnalyzer.analyze(requests);
      expect(result.duplicateGroups, hasLength(1));
      expect(result.duplicateGroups.single.occurrenceCount, 4);
      expect(result.duplicateGroups.single.identicalResponseCount, 4);
      final findings = result.findingsOf(ApiIntelligenceCategory.redundancy);
      expect(findings, isNotEmpty);
      expect(findings.first.observation, contains('Potential redundant'));
    });

    test('does not group requests with different query parameters', () {
      final result = ApiIntelligenceAnalyzer.analyze([
        _req(queryParameters: const {'page': '1'}),
        _req(queryParameters: const {'page': '2'}),
      ]);
      expect(result.duplicateGroups, isEmpty);
    });
  });

  group('ApiIntelligenceAnalyzer - status codes & reliability', () {
    test('aggregates status code distribution per endpoint', () {
      final requests = [
        _req(statusCode: 200),
        _req(statusCode: 200),
        _req(statusCode: 404),
      ];
      final result = ApiIntelligenceAnalyzer.analyze(requests);
      final metrics = result.endpointMetrics.single;
      expect(metrics.statusCodeCounts[200], 2);
      expect(metrics.statusCodeCounts[404], 1);
    });

    test('flags high server-error rate as high priority reliability finding',
        () {
      final requests = [
        for (var i = 0; i < 5; i++) _req(statusCode: 500),
      ];
      final result = ApiIntelligenceAnalyzer.analyze(requests);
      final findings = result.findingsOf(ApiIntelligenceCategory.reliability);
      expect(
        findings.any(
            (f) => f.severity == FindingSeverity.highPriorityInvestigation),
        isTrue,
      );
    });

    test('a single 404 is not flagged (needs repeated evidence)', () {
      final result = ApiIntelligenceAnalyzer.analyze([
        _req(statusCode: 200),
        _req(statusCode: 404),
      ]);
      expect(result.findingsOf(ApiIntelligenceCategory.http), isEmpty);
    });
  });

  group('ApiIntelligenceAnalyzer - retries', () {
    test('detects a chain of failures followed by an eventual success', () {
      final requests = [
        _req(
          statusCode: 500,
          sentTime: DateTime(2026, 1, 1, 10, 0, 0),
          receivedTime: DateTime(2026, 1, 1, 10, 0, 0, 100),
        ),
        _req(
          statusCode: 500,
          sentTime: DateTime(2026, 1, 1, 10, 0, 1),
          receivedTime: DateTime(2026, 1, 1, 10, 0, 1, 100),
        ),
        _req(
          statusCode: 200,
          sentTime: DateTime(2026, 1, 1, 10, 0, 2),
          receivedTime: DateTime(2026, 1, 1, 10, 0, 2, 100),
        ),
      ];
      final result = ApiIntelligenceAnalyzer.analyze(requests);
      expect(result.retryGroups, isNotEmpty);
      expect(result.retryGroups.first.succeededEventually, isTrue);
    });
  });

  group('ApiIntelligenceAnalyzer - caching', () {
    test('flags missing caching headers on a stable, repeated GET endpoint',
        () {
      final requests = [
        for (var i = 0; i < 3; i++)
          _req(responseBody: const {'name': 'stable'}),
      ];
      final result = ApiIntelligenceAnalyzer.analyze(requests);
      final findings = result.findingsOf(ApiIntelligenceCategory.caching);
      expect(findings, isNotEmpty);
    });

    test('does not flag when Cache-Control is present', () {
      final requests = [
        for (var i = 0; i < 3; i++)
          _req(
            responseBody: const {'name': 'stable'},
            responseHeaders: const {'cache-control': 'max-age=60'},
          ),
      ];
      final result = ApiIntelligenceAnalyzer.analyze(requests);
      expect(result.findingsOf(ApiIntelligenceCategory.caching), isEmpty);
    });
  });

  group('ApiIntelligenceAnalyzer - payload & complexity', () {
    test('classifies a very large response and flags it', () {
      final largeList = List.generate(2000, (i) => {'id': i, 'name': 'x' * 50});
      final result = ApiIntelligenceAnalyzer.analyze([
        _req(url: 'https://api.example.com/investments', responseBody: {
          'items': largeList,
        }),
      ]);
      final findings = result.findingsOf(ApiIntelligenceCategory.payload);
      expect(findings, isNotEmpty);
      expect(findings.first.severity,
          anyOf(FindingSeverity.optimizationCandidate,
              FindingSeverity.highPriorityInvestigation));
    });

    test('a small normal response is not flagged as a payload issue', () {
      final result = ApiIntelligenceAnalyzer.analyze([
        _req(responseBody: const {'id': 1, 'name': 'Ahmed'}),
      ]);
      expect(result.findingsOf(ApiIntelligenceCategory.payload), isEmpty);
    });
  });

  group('ApiIntelligenceAnalyzer - pagination', () {
    test('flags a large unpaginated array response', () {
      final items = List.generate(430, (i) => {'id': i});
      final result = ApiIntelligenceAnalyzer.analyze([
        _req(
          url: 'https://api.example.com/investments',
          responseBody: {'items': items},
        ),
      ]);
      final findings = result.findingsOf(ApiIntelligenceCategory.pagination);
      expect(findings, isNotEmpty);
      expect(findings.first.evidence.any((e) => e.contains('430')), isTrue);
    });

    test('notes existing pagination metadata instead of assuming its absence',
        () {
      final items = List.generate(200, (i) => {'id': i});
      final result = ApiIntelligenceAnalyzer.analyze([
        _req(
          url: 'https://api.example.com/investments',
          responseBody: {'items': items, 'page': 1, 'hasMore': true},
        ),
      ]);
      final findings = result.findingsOf(ApiIntelligenceCategory.pagination);
      expect(findings.single.evidence.any((e) => e.contains('pagination')),
          isTrue);
    });
  });

  group('ApiIntelligenceAnalyzer - waterfall', () {
    test('detects a sequential, non-overlapping chain of distinct requests',
        () {
      final result = ApiIntelligenceAnalyzer.analyze([
        _req(
          url: 'https://api.example.com/profile',
          sentTime: DateTime(2026, 1, 1, 10, 0, 0),
          receivedTime: DateTime(2026, 1, 1, 10, 0, 0, 700),
        ),
        _req(
          url: 'https://api.example.com/companies',
          sentTime: DateTime(2026, 1, 1, 10, 0, 0, 700),
          receivedTime: DateTime(2026, 1, 1, 10, 0, 1, 300),
        ),
      ]);
      expect(result.sequentialChains, isNotEmpty);
      expect(result.findingsOf(ApiIntelligenceCategory.waterfall), isNotEmpty);
    });

    test('does not flag overlapping (parallel) requests', () {
      final result = ApiIntelligenceAnalyzer.analyze([
        _req(
          url: 'https://api.example.com/profile',
          sentTime: DateTime(2026, 1, 1, 10, 0, 0),
          receivedTime: DateTime(2026, 1, 1, 10, 0, 1),
        ),
        _req(
          url: 'https://api.example.com/companies',
          sentTime: DateTime(2026, 1, 1, 10, 0, 0),
          receivedTime: DateTime(2026, 1, 1, 10, 0, 1),
        ),
      ]);
      expect(result.findingsOf(ApiIntelligenceCategory.waterfall), isEmpty);
    });
  });

  group('ApiIntelligenceAnalyzer - compression', () {
    test('flags a large response missing Content-Encoding', () {
      final body = {'blob': 'x' * 60000};
      final result = ApiIntelligenceAnalyzer.analyze([
        _req(responseBody: body),
      ]);
      final findings = result.findingsOf(ApiIntelligenceCategory.http);
      expect(
        findings.any((f) => f.observation.contains('Content-Encoding')),
        isTrue,
      );
    });

    test('does not flag when Content-Encoding is present', () {
      final body = {'blob': 'x' * 60000};
      final result = ApiIntelligenceAnalyzer.analyze([
        _req(
          responseBody: body,
          responseHeaders: const {'content-encoding': 'gzip'},
        ),
      ]);
      final findings = result.findingsOf(ApiIntelligenceCategory.http);
      expect(
        findings.any((f) => f.observation.contains('Content-Encoding')),
        isFalse,
      );
    });
  });

  group('ApiIntelligenceAnalyzer - session summary', () {
    test('summarizes request counts and unique endpoints', () {
      final result = ApiIntelligenceAnalyzer.analyze([
        _req(url: 'https://api.example.com/a'),
        _req(url: 'https://api.example.com/a'),
        _req(url: 'https://api.example.com/b'),
      ]);
      expect(result.session.requestCount, 3);
      expect(result.session.uniqueEndpointCount, 2);
    });
  });
}
