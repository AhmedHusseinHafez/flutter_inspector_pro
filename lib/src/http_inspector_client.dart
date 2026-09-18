import 'dart:convert';

import 'package:http/http.dart' as http;

import '../requests_inspector.dart';

/// A `package:http` [http.Client] wrapper that logs every request/response
/// to the Inspector, mirroring what [RequestsInspectorInterceptor] does for
/// Dio. Wrap your existing client (or omit to create a plain one):
///
/// ```dart
/// final client = HttpInspectorClient(http.Client());
/// final response = await client.get(Uri.parse('https://example.com'));
/// ```
class HttpInspectorClient extends http.BaseClient {
  HttpInspectorClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final sentTime = DateTime.now();
    final requestBody = request is http.Request ? request.body : null;

    try {
      final streamedResponse = await _inner.send(request);
      final bodyBytes = await streamedResponse.stream.toBytes();

      InspectorController().addNewRequest(
        RequestDetails(
          requestMethod: _methodFrom(request.method),
          url: request.url.toString().split('?').first,
          headers: request.headers,
          queryParameters: request.url.queryParameters,
          requestBody: _tryDecodeJson(requestBody),
          statusCode: streamedResponse.statusCode,
          responseBody:
              _tryDecodeJson(utf8.decode(bodyBytes, allowMalformed: true)),
          sentTime: sentTime,
          receivedTime: DateTime.now(),
        ),
      );

      return http.StreamedResponse(
        http.ByteStream.fromBytes(bodyBytes),
        streamedResponse.statusCode,
        contentLength: bodyBytes.length,
        request: streamedResponse.request,
        headers: streamedResponse.headers,
        isRedirect: streamedResponse.isRedirect,
        persistentConnection: streamedResponse.persistentConnection,
        reasonPhrase: streamedResponse.reasonPhrase,
      );
    } catch (error) {
      InspectorController().addNewRequest(
        RequestDetails(
          requestMethod: _methodFrom(request.method),
          url: request.url.toString().split('?').first,
          headers: request.headers,
          queryParameters: request.url.queryParameters,
          requestBody: _tryDecodeJson(requestBody),
          statusCode: 0,
          responseBody: error.toString(),
          sentTime: sentTime,
          receivedTime: DateTime.now(),
        ),
      );
      rethrow;
    }
  }

  RequestMethod _methodFrom(String method) {
    return RequestMethod.values.firstWhere(
      (m) => m.name == method.toUpperCase(),
      orElse: () => RequestMethod.GET,
    );
  }

  dynamic _tryDecodeJson(String? body) {
    if (body == null || body.isEmpty) return body;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }
}
