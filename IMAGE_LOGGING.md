# How image request logging works

This is a technical walkthrough of `lib/src/image_http_overrides.dart` and its
two small companions (`image_log_controller.dart`, `image_request_details.dart`)
— the mechanism behind the Inspector's automatic "Images" tab. It exists
because this is the one integration in the package that *isn't* an opt-in
wrapper you add yourself (unlike `RequestsInspectorInterceptor` for Dio or
`HttpInspectorClient` for `package:http`), so it's worth explaining precisely
what it hooks into and why.

## The goal

Log every network image `Image.network`/`NetworkImage` loads, automatically,
with:

- **Zero code changes** in the app using this package.
- **No interference** with the actual image load — same speed, same bytes,
  no risk of corrupting the image.
- **No double-counting** against the opt-in Dio/`http` interceptors, which
  already log plain API traffic.
- A separate place to look (the "Images" tab), since image traffic is
  high-volume and would just be noise mixed into the main "All" timeline.

## Why `HttpOverrides`, and not something else

Flutter's `Image.network`/`NetworkImage` don't accept a custom HTTP client —
internally, they just call `HttpClient()` from `dart:io` and fetch the bytes.
There's no constructor parameter, no injectable client, nothing to wrap from
the call site. So an opt-in wrapper (the pattern used for Dio and
`package:http`) simply isn't available here — you can't hand `Image.network`
a `HttpInspectorClient`.

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
    (response) => _maybeLog(request, response, sentTime),
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
(Flutter's image loader, in this case). It doesn't wrap or proxy the request
object at all — it just also attaches its own listener to
`request.done`, a `Future<HttpClientResponse>` that `dart:io` already exposes
and that completes once the response headers are available. Listening to a
`Future` doesn't consume it or stop anyone else from listening to the same
completion — so the real caller's own `request.close()` (which is what
actually sends the request and resolves that same future) works exactly as
if this override didn't exist. Nothing about the request or response is
touched, copied, or delayed.

## What gets logged, and why only headers

```dart
void _maybeLog(HttpClientRequest request, HttpClientResponse response, DateTime sentTime) {
  try {
    final contentType = response.headers.value('content-type');
    if (contentType == null || !contentType.toLowerCase().startsWith('image/')) {
      return;
    }
    final contentLengthHeader = response.headers.value('content-length');
    ImageLogController.log(ImageRequestDetails(
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

Two deliberate choices here:

1. **Only the `Content-Type` response header decides whether something is
   "an image".** Not the request URL, not a file extension guess — the
   actual header the server sent back. This is what makes the "no
   double-counting" guarantee hold regardless of which client made the
   request: if you fetch a JSON API response through Dio, it's already
   logged by `RequestsInspectorInterceptor`, and this override sees it too
   (since Dio's IO adapter also goes through `HttpClient()`) but silently
   ignores it, because its `Content-Type` isn't `image/*`. Only genuine
   image responses ever reach `ImageLogController.log(...)`.
2. **The response body stream is never read.** `_maybeLog` only touches
   `response.headers` and `response.statusCode` — both available synchronously
   the moment `request.done` resolves, before a single byte of the body has
   been consumed. There's no buffering, no `response.toList()`, nothing that
   would compete with Flutter's own image decoder for the stream. This is
   also why there's no thumbnail data cached anywhere by this mechanism —
   the "Images" tab re-fetches the URL itself (via a plain `Image.network`)
   to render a preview, it doesn't reuse bytes captured here.

The whole thing is also wrapped in a `try/catch` that swallows any exception
silently — a bug in the logging path must never be able to break or delay a
real network request.

## What doesn't get logged

- **Non-image responses** — by design, per above.
- **Failed requests with no response at all** (DNS failure, connection
  refused, timeout before headers arrive) — `request.done`'s `onError`
  callback fires, but at that point there's no `Content-Type` to check, so
  there's genuinely no reliable signal that this *was* an image request.
  Guessing from the URL (e.g. a `.png` extension) was considered and
  rejected — a `/user/avatar` endpoint with no extension is a very common
  image URL, and false positives/negatives either way would undermine the
  "only real image responses show up here" guarantee. These failures are
  silently dropped rather than logged incorrectly.
- **Anything on web.** `dart:io`'s `HttpOverrides`/`HttpClient` don't exist
  on Flutter web (it uses the browser's own networking stack instead), so
  this mechanism is a no-op there. `Image.network` still works on web as
  normal; it's just not observed by this package.

## Where the data goes

`ImageLogController` (`lib/src/image_log_controller.dart`) is a tiny global
store — a capped `ValueNotifier<List<ImageRequestDetails>>` (200 entries max,
oldest dropped first), deliberately kept separate from `InspectorController`.
The Inspector's "Images" tab (`lib/src/shared_widgets/inspector.dart`,
`_buildImagesTab`) just listens to it directly and renders a list.
`ImageLogController.clear()` (or the tab's own "Clear All" action) empties it.

## Summary of the file map

| File | Role |
|---|---|
| `lib/src/image_http_overrides.dart` | `RequestsInspectorHttpOverrides` (the `HttpOverrides` subclass) + `_ObservingHttpClient` (the `HttpClient` wrapper that does the actual observing). |
| `lib/src/image_log_controller.dart` | `ImageLogController` — the `ValueNotifier`-backed store the "Images" tab reads from. |
| `lib/src/image_request_details.dart` | `ImageRequestDetails` — the plain data class for one logged image response. |
| `lib/src/requests_inspector_widget.dart` | Calls `RequestsInspectorHttpOverrides.install()` once, from `RequestsInspector`'s `initState()`. |
| `lib/src/shared_widgets/inspector.dart` | The "Images" tab UI (`_buildImagesTab`) and its list item (`ImageLogItemWidget`). |
