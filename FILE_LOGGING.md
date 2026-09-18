# How file request logging works

This is a technical walkthrough of `lib/src/file_http_overrides.dart` and its
two small companions (`file_log_controller.dart`, `file_request_details.dart`)
— the mechanism behind the Inspector's automatic "Files" tab. It exists
because this is the one integration in the package that *isn't* an opt-in
wrapper you add yourself (unlike `RequestsInspectorInterceptor` for Dio or
`HttpInspectorClient` for `package:http`), so it's worth explaining precisely
what it hooks into and why.

## The goal

Log every network *file* response (images, videos, audio, PDFs, fonts,
archives, downloads, and any other binary asset — not just images), 
automatically, with:

- **Zero code changes** in the app using this package.
- **No interference** with the actual load — same speed, same bytes, no risk
  of corrupting the file.
- **No double-counting** against the opt-in Dio/`http` interceptors, which
  already log plain API traffic.
- A separate place to look (the "Files" tab), since this traffic is
  high-volume and would just be noise mixed into the main "All" timeline.

### Examples of what shows up here

| Kind of file | Typical `Content-Type` |
|---|---|
| Images | `image/png`, `image/jpeg`, `image/webp`, `image/svg+xml` |
| Video | `video/mp4`, `video/quicktime` |
| Audio | `audio/mpeg`, `audio/aac` |
| Documents | `application/pdf` |
| Fonts | `font/woff2`, `font/ttf` |
| Archives / downloads | `application/zip`, `application/gzip`, `application/octet-stream` |

Anything that looks like a plain API response (`application/json`,
`application/graphql`, `application/xml`/`text/xml`, `text/html`,
`text/plain`, `application/x-www-form-urlencoded`) is deliberately excluded —
see "What gets logged, and why only headers" below.

## Why `HttpOverrides`, and not something else

Flutter's `Image.network`/`NetworkImage` (and most other file loads apps make
directly via `dart:io`) don't accept a custom HTTP client — internally, they
just call `HttpClient()` from `dart:io` and fetch the bytes. There's no
constructor parameter, no injectable client, nothing to wrap from the call
site. So an opt-in wrapper (the pattern used for Dio and `package:http`)
simply isn't available here.

`dart:io` does give you exactly one global seam for this: `HttpOverrides`.

```dart
abstract class HttpOverrides {
  static HttpOverrides? get current;
  static set global(HttpOverrides? overrides);

  HttpClient createHttpClient(SecurityContext? context);
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment);
}
```

Whenever *anything* in the process calls the `HttpClient()` factory
constructor — Flutter's image loader, Dio's default IO adapter, `package:http`'s
`IOClient`, or your own code — it checks `HttpOverrides.current` first and,
if one is set, asks it for the client instead of constructing the real one
directly. Setting `HttpOverrides.global` is the *only* place in the whole
`dart:io` HTTP stack where you can intercept "give me an HttpClient" without
threading a parameter through every call site. This is also literally how
Flutter DevTools' own network view captures traffic it didn't get an explicit
hook for.

## What gets installed, and when

```dart
// lib/src/requests_inspector_widget.dart
@override
void initState() {
  super.initState();
  if (widget._enabled) RequestsInspectorHttpOverrides.install();
}
```

`RequestsInspector.initState()` calls `RequestsInspectorHttpOverrides.install()`
once. `install()` is guarded by a static `_installed` flag so calling it
again (e.g. if `RequestsInspector` rebuilds) is a no-op:

```dart
static bool _installed = false;

static void install() {
  if (_installed) return;
  _installed = true;
  HttpOverrides.global = RequestsInspectorHttpOverrides(HttpOverrides.current);
}
```

The important detail: it captures `HttpOverrides.current` — whatever was set
*before* this call — and passes it in as `_previous`. If the host app already
set its own `HttpOverrides` (for certificate pinning, a proxy, whatever),
this wraps that instead of clobbering it. Every method below either delegates
to `_previous` first (falling back to the real platform behavior via `super`
if there wasn't one) or forwards straight to it, so nothing about the host
app's own override is lost — this override is purely additive.

```dart
@override
HttpClient createHttpClient(SecurityContext? context) {
  final previous = _previous;
  final inner = previous != null
      ? previous.createHttpClient(context)
      : super.createHttpClient(context);
  return _ObservingHttpClient(inner);
}
```

`createHttpClient` is the one method that actually matters here: whatever
real `HttpClient` *would* have been created (either the platform default via
`super.createHttpClient`, or whatever the host app's own override would have
produced), it gets wrapped in `_ObservingHttpClient` before being handed back.
From this point on, every `HttpClient()` constructed anywhere in the app is
actually one of these wrappers.

## `_ObservingHttpClient`: a transparent pass-through, mostly

`HttpClient` is a fairly large interface — connection timeouts, proxy
settings, TLS callbacks, and 14 different "open a request" methods
(`open`/`openUrl`, plus `get`/`post`/`put`/`delete`/`patch`/`head` each in a
`(host, port, path)` and a `Url(Uri)` flavor). `_ObservingHttpClient
implements HttpClient` and forwards essentially everything straight to the
real, wrapped client (`_inner`) unchanged — `idleTimeout`, `userAgent`,
`badCertificateCallback`, `close()`, all of it. The *only* methods that do
anything different are the 14 request-opening ones, and they all funnel
through one helper:

```dart
Future<HttpClientRequest> _observe(Future<HttpClientRequest> future) async {
  final request = await future;
  final sentTime = DateTime.now();
  request.done.then(
    (response) => _log(request, response, sentTime),
    onError: (_) { /* see "What doesn't get logged" below */ },
  );
  return request;
}

@override
Future<HttpClientRequest> getUrl(Uri url) => _observe(_inner.getUrl(url));
// ...and the same one-liner for open/openUrl/post/postUrl/put/putUrl/
// delete/deleteUrl/patch/patchUrl/head/headUrl.
```

This is the key trick that keeps the whole thing non-invasive: `_observe`
gets the **real** `HttpClientRequest` from the real inner client and returns
that *exact same object*, unmodified, to whoever called `getUrl`/`get`/etc.
It doesn't wrap or proxy the request object at all — it just also attaches
its own listener to `request.done`, a `Future<HttpClientResponse>` that
`dart:io` already exposes and that completes once the response headers are
available. Listening to a `Future` doesn't consume it or stop anyone else
from listening to the same completion — so the real caller's own
`request.close()` (which is what actually sends the request and resolves
that same future) works exactly as if this override didn't exist. Nothing
about the request or response is touched, copied, or delayed.

## What gets logged, and why only headers

```dart
static const _apiContentTypePrefixes = [
  'application/json',
  'application/graphql',
  'application/x-www-form-urlencoded',
  'text/plain',
  'text/html',
  'text/xml',
  'application/xml',
];

void _log(HttpClientRequest request, HttpClientResponse response, DateTime sentTime) {
  try {
    final contentType = response.headers.value('content-type');
    if (contentType == null || _looksLikeApiResponse(contentType)) return;

    final contentLengthHeader = response.headers.value('content-length');
    FileLogController.log(FileRequestDetails(
      url: request.uri.toString(),
      statusCode: response.statusCode,
      contentType: contentType,
      contentLength: contentLengthHeader != null ? int.tryParse(contentLengthHeader) : null,
      sentTime: sentTime,
      receivedTime: DateTime.now(),
    ));
  } catch (_) {
    // Never let observation break the real request.
  }
}
```

Three deliberate choices here:

1. **The `Content-Type` response header decides what's "a file".** Not the
   request URL, not a file extension guess — the actual header the server
   sent back.
2. **Typical API content-types are excluded, rather than only allowing
   `image/*`.** This is what makes the "no double-counting" guarantee hold
   regardless of which client made the request: if you fetch a JSON API
   response through Dio, it's already logged by
   `RequestsInspectorInterceptor`, and this override sees it too (since
   Dio's IO adapter also goes through `HttpClient()`) but silently ignores
   it, because its `Content-Type` matches one of the excluded API prefixes.
   Everything else — images, video, audio, PDFs, fonts, archives,
   `application/octet-stream`, and any other binary content-type not on that
   list — is treated as a file and logged.
3. **The response body stream is never read.** `_log` only touches
   `response.headers` and `response.statusCode` — both available synchronously
   the moment `request.done` resolves, before a single byte of the body has
   been consumed. There's no buffering, no `response.toList()`, nothing that
   would compete with the real consumer (e.g. Flutter's image decoder) for
   the stream. This is also why there's no data cached anywhere by this
   mechanism — the "Files" tab's image preview re-fetches the URL itself
   (via a plain `Image.network`) to render a thumbnail, it doesn't reuse
   bytes captured here; non-image files just show a type icon instead.

The whole thing is also wrapped in a `try/catch` that swallows any exception
silently — a bug in the logging path must never be able to break or delay a
real network request.

## What doesn't get logged

- **API-shaped responses** (JSON/XML/HTML/plain text/form-encoded) — by
  design, per above, since the opt-in interceptors already cover those.
- **Responses with no `Content-Type` header** — there's no reliable signal
  to classify them, so they're skipped rather than guessed.
- **Failed requests with no response at all** (DNS failure, connection
  refused, timeout before headers arrive) — `request.done`'s `onError`
  callback fires, but at that point there's no `Content-Type` to check, so
  there's genuinely no reliable signal about what this request was for.
  Guessing from the URL (e.g. a `.png` extension) was considered and
  rejected — a `/user/avatar` endpoint with no extension is a very common
  file URL, and false positives/negatives either way would undermine the
  "only real, classifiable responses show up here" guarantee. These
  failures are silently dropped rather than logged incorrectly.
- **Anything on web.** `dart:io`'s `HttpOverrides`/`HttpClient` don't exist
  on Flutter web (it uses the browser's own networking stack instead), so
  this mechanism is a no-op there. File loads still work on web as normal;
  they're just not observed by this package.

## Where the data goes

`FileLogController` (`lib/src/file_log_controller.dart`) is a tiny global
store — a capped `ValueNotifier<List<FileRequestDetails>>` (200 entries max,
oldest dropped first), deliberately kept separate from `InspectorController`.
The Inspector's "Files" tab (`lib/src/shared_widgets/inspector.dart`,
`_buildFilesTab`) just listens to it directly and renders a list.
`FileLogController.clear()` (or the tab's own "Clear All" action) empties it.

## Summary of the file map

| File | Role |
|---|---|
| `lib/src/file_http_overrides.dart` | `RequestsInspectorHttpOverrides` (the `HttpOverrides` subclass) + `_ObservingHttpClient` (the `HttpClient` wrapper that does the actual observing). |
| `lib/src/file_log_controller.dart` | `FileLogController` — the `ValueNotifier`-backed store the "Files" tab reads from. |
| `lib/src/file_request_details.dart` | `FileRequestDetails` — the plain data class for one logged file response. |
| `lib/src/requests_inspector_widget.dart` | Calls `RequestsInspectorHttpOverrides.install()` once, from `RequestsInspector`'s `initState()`. |
| `lib/src/shared_widgets/inspector.dart` | The "Files" tab UI (`_buildFilesTab`) and its list item (`FileLogItemWidget`). |
| `lib/src/shared_widgets/file_log_item.dart` | `FileLogItemWidget` (list row) and `FileTypeIcon` (picks an icon per `Content-Type` for non-image files). |
| `lib/src/shared_widgets/file_request_details_page.dart` | `FileRequestDetailsPage` — the Details tab view for a selected file (preview/icon, metadata, error, copy URL). |
