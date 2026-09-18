import 'dart:io';

import 'file_log_controller.dart';
import 'file_request_details.dart';

/// Installs a global [HttpOverrides] that observes every `dart:io`
/// [HttpClient] request/response in the app - including the ones Flutter's
/// own `Image.network`/`NetworkImage` makes internally - the same mechanism
/// Flutter DevTools' network view relies on. No code changes are required
/// from the app: wrapping it in `RequestsInspector` is enough.
///
/// Responses whose `Content-Type` doesn't look like a typical API response
/// (JSON/XML/HTML/form-encoded) are recorded (into [FileLogController],
/// shown in the Inspector's "Files" tab). That exclusion, not a
/// file-type-specific one, is what keeps this from duplicating what the
/// opt-in interceptors ([RequestsInspectorInterceptor], [HttpInspectorClient])
/// already log for plain API traffic - Dio's default adapter also goes
/// through `dart:io`'s [HttpClient], so without it every API call would be
/// logged twice. Only response *headers* are inspected - the response body
/// stream itself is never read or buffered here, so this can't corrupt or
/// slow down the actual file/data being loaded.
///
/// Typical things that show up here: images (`image/*`), videos, audio,
/// PDFs, fonts, archives (zip), and any other binary file/asset/download
/// fetched over `dart:io`'s `HttpClient` that isn't already routed through
/// the opt-in interceptors.
class RequestsInspectorHttpOverrides extends HttpOverrides {
  RequestsInspectorHttpOverrides(this._previous);

  final HttpOverrides? _previous;

  static bool _installed = false;

  /// Idempotent: safe to call every time `RequestsInspector` builds.
  /// Chains with whatever [HttpOverrides.current] was already set (e.g. a
  /// host app's own certificate pinning), instead of replacing it.
  static void install() {
    if (_installed) return;
    _installed = true;
    HttpOverrides.global =
        RequestsInspectorHttpOverrides(HttpOverrides.current);
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final previous = _previous;
    final inner = previous != null
        ? previous.createHttpClient(context)
        : super.createHttpClient(context);
    return _ObservingHttpClient(inner);
  }

  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    return _previous?.findProxyFromEnvironment(url, environment) ??
        super.findProxyFromEnvironment(url, environment);
  }
}

class _ObservingHttpClient implements HttpClient {
  _ObservingHttpClient(this._inner);

  final HttpClient _inner;

  /// Content-Type prefixes typical of plain API responses, which are
  /// already logged by the opt-in interceptors. Anything else (images,
  /// video, audio, PDFs, fonts, archives, octet-stream, ...) is treated as
  /// a "file" and recorded here.
  static const _apiContentTypePrefixes = [
    'application/json',
    'application/graphql',
    'application/x-www-form-urlencoded',
    'text/plain',
    'text/html',
    'text/xml',
    'application/xml',
  ];

  Future<HttpClientRequest> _observe(Future<HttpClientRequest> future) async {
    final request = await future;
    final sentTime = DateTime.now();
    request.done.then(
      (response) => _log(request, response, sentTime),
      onError: (_) {
        // A failed load with no response headers can't be described
        // reliably, so it's intentionally not logged here to avoid
        // guessing based on the URL alone.
      },
    );
    return request;
  }

  void _log(
    HttpClientRequest request,
    HttpClientResponse response,
    DateTime sentTime,
  ) {
    try {
      final contentType = response.headers.value('content-type');
      if (contentType == null || _looksLikeApiResponse(contentType)) return;

      final contentLengthHeader = response.headers.value('content-length');
      FileLogController.log(
        FileRequestDetails(
          url: request.uri.toString(),
          statusCode: response.statusCode,
          contentType: contentType,
          contentLength: contentLengthHeader != null
              ? int.tryParse(contentLengthHeader)
              : null,
          sentTime: sentTime,
          receivedTime: DateTime.now(),
        ),
      );
    } catch (_) {
      // Never let observation break the real request.
    }
  }

  bool _looksLikeApiResponse(String contentType) {
    final normalized = contentType.toLowerCase();
    return _apiContentTypePrefixes
        .any((prefix) => normalized.startsWith(prefix));
  }

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) =>
      _observe(_inner.open(method, host, port, path));

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      _observe(_inner.openUrl(method, url));

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      _observe(_inner.get(host, port, path));

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _observe(_inner.getUrl(url));

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      _observe(_inner.post(host, port, path));

  @override
  Future<HttpClientRequest> postUrl(Uri url) => _observe(_inner.postUrl(url));

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      _observe(_inner.put(host, port, path));

  @override
  Future<HttpClientRequest> putUrl(Uri url) => _observe(_inner.putUrl(url));

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      _observe(_inner.delete(host, port, path));

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) =>
      _observe(_inner.deleteUrl(url));

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      _observe(_inner.patch(host, port, path));

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => _observe(_inner.patchUrl(url));

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      _observe(_inner.head(host, port, path));

  @override
  Future<HttpClientRequest> headUrl(Uri url) => _observe(_inner.headUrl(url));

  // --- Everything else is a plain pass-through to the wrapped client. ---

  @override
  Duration get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;

  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  set authenticate(
          Future<bool> Function(Uri url, String scheme, String? realm)? f) =>
      _inner.authenticate = f;

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) =>
      _inner.addCredentials(url, realm, credentials);

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
            Uri url, String? proxyHost, int? proxyPort)?
        f,
  ) =>
      _inner.connectionFactory = f;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  set authenticateProxy(
    Future<bool> Function(String host, int port, String scheme, String? realm)?
        f,
  ) =>
      _inner.authenticateProxy = f;

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) =>
      _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) =>
      _inner.badCertificateCallback = callback;

  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;

  @override
  void close({bool force = false}) => _inner.close(force: force);
}
