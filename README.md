# flutter_inspector_pro

An in-app network inspector for Flutter apps. Long-press anywhere on screen and get a live, on-device timeline of everything your app talks to over the network — REST (`Dio` and `package:http`), **GraphQL** (queries, mutations, and WebSocket subscriptions), **Server-Sent Events (SSE)**, and **network files** (images, videos, PDFs, fonts, downloads, ... — logged automatically, no code changes needed) — with request/response detail views, request/response interception ("Stopper"), search & filtering, and one-tap share-to-Slack. No external proxy tool (Charles, Proxyman, mitmproxy) required.

> **📌 Provenance note — please read.** This package is a fork built on top of [`requests_inspector`](https://github.com/Abdelazeem777/requests_inspector) by **Abdelazeem Kuratem** and its contributors. The original author of *this* fork built its architecture and feature set independently, but later found that upstream's GraphQL integration was a stronger implementation than what existed here, and adopted it rather than keep maintaining a separate, weaker one. Upstream's GraphQL link (`GraphQLInspectorLink`), the base inspector shell, the Dio interceptor, and the Stopper feature all originate there — **this fork does not claim to have invented that code.** Everything else described below as "added in this fork" (the `package:http` client, SSE support, search/filtering, HAR export, the current UI, and more) was built independently on top of that adopted base. See [Credits & Relationship to the Upstream Project](#-credits--relationship-to-the-upstream-project) for the full, itemized breakdown, and give the [Contributors](#-contributors) section below a look — it lists everyone who has worked on upstream.

---

## Table of contents

- [What this package does](#what-this-package-does)
- [Architecture, in brief](#architecture-in-brief)
- [Features](#features)
- [Getting started](#getting-started)
- [Usage](#usage)
  - [REST — Dio](#1-rest--dio)
  - [REST — package:http](#2-rest--packagehttp)
  - [Manual logging (any transport)](#3-manual-logging-any-transport)
  - [GraphQL — graphql_flutter](#4-graphql--graphql_flutter)
  - [Server-Sent Events / streaming logs](#5-server-sent-events--streaming-logs)
  - [Stopper — intercept requests & responses](#6-stopper--intercept-requests--responses)
  - [File network logging (automatic)](#7-file-network-logging-automatic)
  - [Firebase Messaging Inspector (opt-in)](#8-firebase-messaging-inspector-opt-in)
- [Filtering & search](#filtering--search)
- [Sharing & exporting requests](#sharing--exporting-requests)
- [Credits & Relationship to the Upstream Project](#-credits--relationship-to-the-upstream-project)
- [🤝 Contributors](#-contributors)
- [Roadmap](#roadmap)
- [License](#license)

---

## What this package does

Wrap your `MaterialApp` in `RequestsInspector` and every request your app makes through a supported client gets recorded — method, URL, query parameters, headers, request/response bodies, status code, and timing — into an in-memory timeline. Long-press anywhere to bring up the inspector screen on top of your running app, browse the timeline, drill into a single request's (or SSE connection's) details (with a JSON tree view or raw text), search across everything, filter by method/status/type, and share it straight to Slack with one tap.

It's aimed at day-to-day development and QA: reproducing a bug on a real device/simulator without hooking up a system-wide proxy, showing a backend engineer exactly what a mobile client sent, or forcing a specific response/error to test how the UI handles it (via **Stopper**).

## Architecture, in brief

- **`InspectorController`** — a singleton `ChangeNotifier` (exposed via `provider`) that holds the in-memory list of logged requests, the currently selected request/SSE connection, search/filter state, and the Stopper's enabled/filter state. It's the single source of truth the whole inspector UI reads from.
- **`RequestsInspector`** — the widget you wrap your app in. It creates the `InspectorController`, listens for the long-press gesture, and pushes the `Inspector` screen (a `Scaffold` with an "All" timeline tab and a "Details" tab) on top of your navigator when triggered.
- **Per-transport loggers, all opt-in** — instead of one global hook that intercepts everything (which would be fragile and easy to double-count), each supported transport has its own small wrapper you explicitly add: `RequestsInspectorInterceptor` (Dio), `HttpInspectorClient` (`package:http`), `GraphQLInspectorLink` (GraphQL), and `SseLogController.log(...)` (SSE/streaming, called manually since there's no single standard SSE client in the Flutter ecosystem). Anything not covered by one of these can still be logged by calling `InspectorController().addNewRequest(...)` directly.
- **The one exception: file logging is automatic, not opt-in** — `RequestsInspectorHttpOverrides` installs a global `dart:io` `HttpOverrides` (the same mechanism Flutter DevTools' network view uses) that observes every `HttpClient` request in the app, including the one `Image.network`/`NetworkImage` uses internally. It only reads response *headers* (never the body stream) and records any entry whose `Content-Type` doesn't look like a plain API response (JSON/XML/HTML/form-encoded), into a separate `FileLogController` — covering images, video, audio, PDFs, fonts, archives, and other downloads, so it can't slow down loading and never mixes into, or double-counts against, the opt-in loggers above. See [File network logging](#7-file-network-logging-automatic).
- **Presentation** — the inspector screen itself doesn't know or care which transport a given entry came from; it renders whatever `RequestDetails` objects are in the controller's list (plus SSE connections from `SseLogController` and Firebase Messaging events from `FirebaseMessagingLogController`, both merged into the same timeline and distinguished by a small colored badge). File loads are the one category kept out of that merged timeline on purpose, in their own "Files" tab, since that traffic tends to be high-volume and would just be noise in "All".
- **Firebase Messaging is opt-in and fully decoupled** — `FirebaseMessagingInspector` auto-attaches to `FirebaseMessaging.instance`'s streams only when you pass `firebaseMessaging: FirebaseMessagingInspectorConfig(enabled: true)` to `RequestsInspector`. Unlike the per-transport loggers above, no wrapper object is needed in your own code for foreground events - see [Firebase Messaging Inspector](#8-firebase-messaging-inspector-opt-in) for what that means for background messages specifically.

## Features

- **REST over Dio** — `RequestsInspectorInterceptor`, a standard `dio.Interceptor`.
- **REST over `package:http`** — `HttpInspectorClient`, a drop-in `http.Client`/`BaseClient` wrapper. *(added in this fork)*
- **GraphQL over `graphql`/`graphql_flutter`** — `GraphQLInspectorLink`, covering HTTP queries/mutations and WebSocket subscriptions, with variables shown separately from the query document. *(from upstream)*
- **Server-Sent Events / streaming logs** — `SseLogController`, a lightweight global log sink that groups raw log lines into per-connection timelines (grouped whenever a line contains a `CONNECTING -> <url>` marker), merged into the same "All" timeline as HTTP/GraphQL traffic. *(added in this fork)*
- **Automatic network file logging** — every `Image.network`/`NetworkImage` load and any other non-API file (video, audio, PDF, font, archive, download, ...) fetched over `dart:io`'s `HttpClient` is logged to its own "Files" tab automatically, with zero code changes, via a global `HttpOverrides` — the same mechanism Flutter DevTools' network view uses. *(added in this fork)*
- **Firebase Messaging Inspector (opt-in)** — automatically captures `FirebaseMessaging.onMessage`, `onMessageOpenedApp`, and `getInitialMessage()` with no listener code required, plus a helper for logging `onBackgroundMessage`. Shows message ID, sender ID, `from`, sent time, TTL, collapse key, message type, data payload, and Android/APNs notification details, merged into the same "All" timeline. Off by default; data payload keys that look sensitive are redacted automatically. *(added in this fork; see [Firebase Messaging Inspector](#8-firebase-messaging-inspector-opt-in))*
- **Manual logging** — push a `RequestDetails` into `InspectorController` for any transport not covered above (this is also how the `QUERY` pseudo-method is logged in the example app).
- **`RequestMethod.QUERY`** — an extra pseudo-method for read-only requests that carry a body (distinct from `GET`), alongside `GET`/`POST`/`PUT`/`PATCH`/`DELETE` and the internally-used `WS`. *(added in this fork)*
- **Stopper** — pause an outgoing request or an incoming response and edit it before it continues, useful for forcing error codes or malformed payloads without touching a backend. *(from upstream; see the [Stopper section](#6-stopper--intercept-requests--responses) below for how it's actually enabled in the current version — it's programmatic, not a UI toggle right now)*
- **Search & filtering** — free-text URL search on the timeline, method/status-code/item-type (`all`/`http`/`sse`) filters, and in-request text search with match count and next/previous navigation. *(added in this fork)*
- **Share to Slack** — one tap shares the selected request (or SSE connection) as a ready-to-paste cURL command plus full request/response (or event) log, no format picker in the way. *(reworked in this fork; see [Sharing & exporting requests](#sharing--exporting-requests))*
- JSON tree view (or raw text) with copy-to-clipboard per section, light/dark themes, and `onInspectorOpened`/`onInspectorClosed` callbacks. *(callbacks added in this fork)*

## Getting started

Wrap your `MaterialApp` with `RequestsInspector` inside its `builder`, so the inspector overlay sits above your navigator. A `navigatorKey` is **required** — it's how the inspector presents itself and, if you use it, the Stopper's edit dialogs.

```dart
final navigatorKey = GlobalKey<NavigatorState>();

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) {
        return RequestsInspector(
          enabled: true,
          navigatorKey: navigatorKey,
          child: child!,
        );
      },
      home: const HomePage(),
    );
  }
}
```

Open the inspector by **long-pressing** any free space on screen.

> ⚠️ **Gotcha:** `InspectorController` is a singleton created the first time anything calls `InspectorController(...)`. If your own code calls it (directly, or indirectly through `addNewRequest`/an interceptor) *before* `RequestsInspector` has actually built — for example, synchronously in a top-level `initState()`, ahead of the widget tree — it gets created with default arguments instead of the ones you passed to `RequestsInspector`. In practice: defer any such calls to after the first frame (e.g. `WidgetsBinding.instance.addPostFrameCallback`), or trigger them from a user action instead of `initState`.

### `RequestsInspector` parameters

| Parameter | Default | Purpose |
|---|---|---|
| `enabled` | `true` | Turn the whole inspector on/off (e.g. disable in release builds). |
| `navigatorKey` | required | Used to present the inspector screen and the Stopper edit dialogs. |
| `showInspectorOn` | `ShowInspectorOn.LongPress` | Kept for API compatibility; opening is long-press only — see note below. |
| `hideInspectorBanner` | `false` | Hides the "INSPECTOR" corner banner. |
| `defaultTreeViewEnabled` | `true` | Whether JSON bodies default to tree view vs. raw text. |
| `defaultExpandChildren` | `true` | Whether JSON tree nodes start expanded. |
| `defaultIsDarkMode` | `true` | Initial inspector theme. |
| `onInspectorOpened` / `onInspectorClosed` | — | Callbacks fired when the inspector screen opens/closes. |
| `firebaseMessaging` | `FirebaseMessagingInspectorConfig()` (disabled) | Opt-in Firebase Messaging capture — see [Firebase Messaging Inspector](#8-firebase-messaging-inspector-opt-in). |

`ShowInspectorOn.Shaking` and `ShowInspectorOn.Both` still exist as enum values for source compatibility with older code, but behave exactly like `ShowInspectorOn.LongPress` now — shake-to-open (and its `sensors_plus` dependency) was removed in this fork; long-press is the only trigger.

---

## Usage

### 1. REST — Dio

```dart
final dio = Dio()..interceptors.add(RequestsInspectorInterceptor());
```

Every request/response through this Dio instance is logged automatically, including failed requests (via `onError`).

### 2. REST — `package:http`

```dart
final client = HttpInspectorClient(http.Client());
final response = await client.get(Uri.parse('https://dummyjson.com/posts'));
```

`HttpInspectorClient` extends `http.BaseClient`, wrapping an inner `http.Client` (or creating a plain one if you don't pass one) and mirroring every call — including network errors, logged with `statusCode: 0` — into the inspector. It's a drop-in replacement anywhere you'd use an `http.Client`.

### 3. Manual logging (any transport)

```dart
InspectorController().addNewRequest(
  RequestDetails(
    requestName: 'Posts',
    requestMethod: RequestMethod.GET,
    url: apiUrl,
    queryParameters: params,
    statusCode: responseStatusCode,
    responseBody: responseData,
  ),
);
```

`RequestMethod` covers `GET`, `POST`, `PATCH`, `PUT`, `DELETE`, plus `QUERY` (a read-only request that carries a body — added in this fork) and `WS` (used internally for GraphQL subscriptions).

### 4. GraphQL — `graphql_flutter`

Wrap your `HttpLink` (and, for subscriptions, your `WebSocketLink`) with `GraphQLInspectorLink`:

```dart
final client = GraphQLClient(
  cache: GraphQLCache(),
  link: Link.split(
    (request) => request.isSubscription,
    GraphQLInspectorLink(WebSocketLink('ws://graphqlzero.almansi.me/api')),
    GraphQLInspectorLink(HttpLink('https://graphqlzero.almansi.me/api')),
  ),
);

const query = r'''query GetPost($id: ID!) {
  post(id: $id) {
    id
    title
    body
  }
}''';

final result = await client.query(
  QueryOptions(document: gql(query), variables: {'id': 1}),
);
```

The inspector logs the operation name, the printed GraphQL document, variables, response, headers, status code, and sent/received timestamps for both HTTP and WebSocket traffic. **This integration is adopted from the upstream project** — see [Credits](#-credits--relationship-to-the-upstream-project).

### 5. Server-Sent Events / streaming logs

```dart
SseLogController.log('CONNECTING -> wss://example.com/stream/prices');
SseLogController.log('event: price_update {"symbol":"BTC","price":67210}');
SseLogController.log('CLOSED');
```

There's no single standard SSE client across the Flutter ecosystem, so unlike Dio/`http`, this is manual: call `SseLogController.log(...)` with whatever line you want recorded, from wherever your SSE/streaming client emits events. The inspector groups consecutive lines into one connection entry whenever it sees a `CONNECTING -> <url>` marker, and shows those connections alongside HTTP/GraphQL traffic in the same "All" timeline (filterable to SSE-only via the item-type filter). Use `SseLogController.clear()` to wipe the whole log, or `SseLogController.removeConnection(connection)` to drop one grouped connection (e.g. via swipe-to-dismiss in the timeline).

### 6. Stopper — intercept requests & responses

Pause an outgoing request or an incoming response and edit it in a dialog before it continues — useful for simulating errors or edge-case payloads without changing your backend.

In the current version of this fork, Stopper is **programmatic** — there is no inspector-UI toggle for it right now (an earlier "⋮" overflow menu exposed this, but it was removed when the UI was simplified). Enable it from your own code:

```dart
// Turn stopping on for requests and/or responses.
InspectorController().requestStopperEnabled = true;
InspectorController().responseStopperEnabled = true;

// Optionally scope which requests/responses actually get intercepted.
InspectorController().setRequestStopperFilterMethod(RequestMethod.POST);
InspectorController().setRequestStopperFilterUrl('/checkout');
InspectorController().setResponseStopperFilterStatusCode(200);
```

With `requestStopperEnabled`/`responseStopperEnabled` on, a matching in-flight request/response pauses and `RequestStopperEditorDialog`/`ResponseStopperEditorDialog` is shown (via your `navigatorKey`), letting you edit the body/headers/status before it continues.

### 7. File network logging (automatic)

There's nothing to call here — this is the one integration that isn't opt-in. As soon as your app is wrapped in `RequestsInspector`, every network *file* load anywhere in the app (via `Image.network`, `NetworkImage`, a direct `dart:io` `HttpClient` download, or any other code using `dart:io`'s `HttpClient`) shows up in the Inspector's **"Files"** tab: URL, content type, size, status, and a preview (a thumbnail for images, a type icon otherwise).

```dart
// Nothing to change here - these already get logged automatically:
Image.network('https://example.com/avatar.png');
await httpClient.getUrl(Uri.parse('https://example.com/report.pdf'));
```

This covers more than images — anything whose response doesn't look like a typical API call shows up here, for example:

| Kind of file | Example `Content-Type` |
|---|---|
| Images | `image/png`, `image/jpeg`, `image/webp` |
| Video | `video/mp4` |
| Audio | `audio/mpeg` |
| PDFs / documents | `application/pdf` |
| Fonts | `font/woff2` |
| Archives / downloads | `application/zip`, `application/octet-stream` |

Under the hood, `RequestsInspectorHttpOverrides.install()` sets a global `HttpOverrides` that wraps every `HttpClient` created in the app and inspects each response's headers (never the body). Responses that look like plain API traffic (`application/json`, `application/graphql`, `application/xml`/`text/xml`, `text/html`, `text/plain`, form-encoded) are skipped, and everything else is logged to `FileLogController` — a separate store from `InspectorController`, so this traffic never crowds the "All" timeline or duplicates what `RequestsInspectorInterceptor`/`HttpInspectorClient` already log for API calls. If your app sets its own `HttpOverrides.global` (e.g. for certificate pinning), install this one afterwards, or expect `RequestsInspector` (which installs it in `initState`) to chain onto whatever override already exists at that point.

Clear the log from the "Files" tab's "Clear All" action, or programmatically with `FileLogController.clear()`.

For a full technical walkthrough of exactly how this hooks into `dart:io` without touching the response body or double-counting other traffic, see [FILE_LOGGING.md](FILE_LOGGING.md).

### 8. Firebase Messaging Inspector (opt-in)

This package doesn't depend on Firebase for its core functionality, but `firebase_messaging` **is** a direct dependency of the package (so this feature is fully type-safe) - it just does nothing unless you enable it. If your app already uses `firebase_messaging`, you can inspect FCM traffic with one extra parameter and no listener code:

```dart
RequestsInspector(
  navigatorKey: navigatorKey,
  firebaseMessaging: const FirebaseMessagingInspectorConfig(enabled: true),
  child: child,
)
```

Firebase must already be initialized (`await Firebase.initializeApp()`) by the time `RequestsInspector` builds - it's meant to run after your app's own Firebase setup, same as any other Firebase-dependent code. If it isn't ready yet, the inspector just skips attaching instead of throwing.

With this enabled, the inspector automatically logs, with no `FirebaseMessaging.onMessage.listen(...)` code of your own:

- **`FirebaseMessaging.onMessage`** — foreground messages.
- **`FirebaseMessaging.onMessageOpenedApp`** — messages that launched/resumed the app via a notification tap.
- **`getInitialMessage()`** — the message that cold-started the app, if any.

For each event it records: message ID, sender ID, `from`, sent time, TTL, collapse key, message type, the data payload, and (when present) the notification's title/body plus Android (`channelId`, `imageUrl`, `priority`, …) and Apple/APNs (`badge`, `subtitle`) details. These show up in the same "All" timeline as HTTP/GraphQL/SSE traffic, tagged `Firebase Messaging`, filterable via the item-type filter, with their own detail page and Slack share support.

**Data payload masking.** FCM `data` payloads are a common place for apps to smuggle short-lived secrets (auth tokens, one-time codes). By default, any data key whose name contains `token`, `password`, `secret`, `authorization`, `api_key`, `apikey`, `access_token`, or `refresh_token` (case-insensitive) has its value replaced with `***` before it's logged. Customize or disable this via `maskedDataKeys`:

```dart
FirebaseMessagingInspectorConfig(
  enabled: true,
  maskedDataKeys: {'token', 'otp'}, // replace the defaults entirely
  // maskedDataKeys: {},            // or disable masking altogether
)
```

**Background messages - a platform limitation, not a package gap.** `FirebaseMessaging.onBackgroundMessage(handler)` requires `handler` to be a top-level or `static` function, because the OS spawns it in a **separate background isolate** that does not share memory with your running app - that's a Flutter/Firebase isolate constraint, not something this package can work around. Two consequences:

1. This package **never calls `FirebaseMessaging.onBackgroundMessage()`** itself, and never will - your app registers its own handler, and this package won't touch or replace it.
2. To still get a structured log entry for background messages, call `FirebaseMessagingInspector.logBackgroundMessage(message)` as the first line of your **own** handler:

    ```dart
    @pragma('vm:entry-point')
    Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
      await FirebaseMessagingInspector.logBackgroundMessage(message);
      // ...the rest of your existing handler logic, unchanged.
    }

    void main() async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      runApp(const MyApp());
    }
    ```

    Because that handler runs in a separate isolate, the entry logged there lives in *that* isolate's memory - **it will not appear in the Inspector UI of your already-running app session.** This is a genuine platform limitation (the same reason background handlers can't touch most of your app's in-memory state), not a bug; it's documented here rather than silently worked around. Foreground events (`onMessage`, `onMessageOpenedApp`, and the initial message on cold start) are unaffected and always show up live.

**Coexisting with your own listeners.** `FirebaseMessaging.onMessage`/`onMessageOpenedApp` are broadcast streams, so this package's internal `.listen(...)` calls run alongside any listeners your own app already has - neither one steals events from the other. Calling `FirebaseMessagingInspector.attach(...)` (which `RequestsInspector` does for you) more than once is also safe; only the first call actually registers listeners.

---

## Filtering & search

- Filter the "All" timeline by HTTP method, status code, and item type (`all` / `http` / `sse` / `firebaseMessaging`), from the filter dialog reachable via the filter icon next to the search bar.
- Free-text URL search across the timeline (HTTP requests only).
- In a request's detail page, search its content with match count and next/previous navigation.

## Sharing & exporting requests

The floating share button (Slack-branded icon) appears on the detail page of any selected item — an HTTP request, an SSE connection, or a Firebase Messaging event — and shares it immediately, with no format picker in the way. The content is built to be pasted straight into a Slack thread and read by another engineer without extra tooling:

- **HTTP requests** — a ready-to-run `cURL` command, followed by the full request/response log (headers, query params, body, status code, timing).
- **SSE connections** — the connection URL, start time, and status, followed by the full chronological event log.
- **Firebase Messaging events** — the event type, metadata (message ID, sender ID, TTL, etc.), notification title/body, and data payload (already masked per your `maskedDataKeys` config).

The share button's icon is Slack's logo, signaling "send this to your team" — but under the hood it still opens the platform's native share sheet (via `share_plus`), so the actual destination app is whatever the user picks there, same as sharing anything else on iOS/Android. It isn't a built-in Slack webhook integration.

---

## 🔧 Credits & Relationship to the Upstream Project

This section exists to be transparent about which parts of this codebase were originated by whom.

- **Upstream project:** [`requests_inspector`](https://github.com/Abdelazeem777/requests_inspector) on pub.dev, by **Abdelazeem Kuratem** ([@Abdelazeem777](https://github.com/Abdelazeem777)) and the contributors listed in [Contributors](#-contributors) below.
- **What comes from upstream, unmodified in origin:**
  - The core inspector architecture: the `InspectorController` singleton/`ChangeNotifier` pattern, the `RequestsInspector` wrapper widget, and the overall inspector-screen shell.
  - The Dio interceptor (`RequestsInspectorInterceptor`) and the `RequestDetails`/`ResponseDetails` data model.
  - The Stopper feature (intercept-and-edit for requests/responses).
  - **The GraphQL integration (`GraphQLInspectorLink`)** — this is the specific piece that prompted this fork. This project originally had its own, separately-maintained GraphQL logging implementation; upstream's turned out to be stronger (HTTP + WebSocket subscription support, variables shown separately from the query). Rather than keep maintaining a weaker implementation in parallel, this fork adopted upstream's `GraphQLInspectorLink` as-is and builds on top of it. **This fork does not claim to have originated `GraphQLInspectorLink` or its design.**
- **Built independently, on top of that adopted base, as part of this fork:**
  - `HttpInspectorClient` — REST request/response logging for `package:http`.
  - Server-Sent Events (SSE) support — `SseLogController` and the connection-grouped SSE timeline entries.
  - The `RequestMethod.QUERY` pseudo-method.
  - `onInspectorOpened` / `onInspectorClosed` callbacks.
  - Search and filtering (URL search, method/status-code/item-type filters, in-request text search with match navigation).
  - Automatic network file logging — `RequestsInspectorHttpOverrides`/`FileLogController` and the "Files" tab (via a global `dart:io` `HttpOverrides`, the same mechanism Flutter DevTools' network view uses).
  - Removal of the shake-to-open gesture and its `sensors_plus` dependency — long-press is now the only way to open the inspector.
  - The current inspector UI (colors, layout, the merged "All" timeline that includes SSE connections, the Slack-branded share button, the redesigned filter/clear dialogs).
  - Migrating off deprecated `share_plus` APIs (`Share.share`/`Share.shareXFiles`) to the current `SharePlus.instance.share(ShareParams(...))` API, and off `WillPopScope` to `PopScope`.
  - **Firebase-backed logging/observability** — planned as a further extension of this fork's own ideas, **not yet implemented**. Listed here so the intent is documented; see [Roadmap](#roadmap).
- Wherever this README describes upstream-derived functionality (GraphQL, the base interceptor, the inspector shell, Stopper), credit belongs to Abdelazeem Kuratem and the contributors below — this fork extends that work rather than having originated it. Conversely, the items listed as "built independently" above are this fork's own work and are not upstream features.
- For the unmodified original package, see https://github.com/Abdelazeem777/requests_inspector.
- This fork's own repository (for issues/PRs specific to the extensions described here) is https://github.com/AhmedHusseinHafez/flutter_inspector_pro.

---

## 🤝 Contributors

Contributors helping improve `requests_inspector`: 💻🎨📖🚧

<table>
  <tr>
    <td align="center">
      <a href="https://github.com/Abdelazeem777">
        <img src="https://avatars.githubusercontent.com/u/30933932?v=4?s=100" width="70px" /><br />
        <sub><b>Abdelazeem</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/BelalNayzak">
        <img src="https://avatars.githubusercontent.com/u/50274195?v=4?s=100" width="70px" /><br />
        <sub><b>Belal</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/MAlazhariy">
        <img src="https://avatars.githubusercontent.com/u/87443208?v=4?s=100" width="70px" /><br />
        <sub><b>Mostafa</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/AbdoTareq">
        <img src="https://avatars.githubusercontent.com/u/29352955?v=4?s=100" width="70px" /><br />
        <sub><b>Abdelrahman</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/Anthony-Chan-Synpulse">
        <img src="https://avatars.githubusercontent.com/u/122436156?v=4?s=100" width="70px" /><br />
        <sub><b>Anthony</b></sub>
      </a>
    </td>
  </tr>
  <tr>
    <td align="center">
      <a href="https://github.com/dev-hussein">
        <img src="https://avatars.githubusercontent.com/u/6766413?v=4?s=100" width="70px" /><br />
        <sub><b>M Hussein</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/vlytvyne">
        <img src="https://avatars.githubusercontent.com/u/44924680?v=4?s=100" width="70px" /><br />
        <sub><b>Vadym</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/MohamedGawdat">
        <img src="https://avatars.githubusercontent.com/u/10387795?v=4?s=100" width="70px" /><br />
        <sub><b>M Gawdat</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/bonaparta13">
        <img src="https://avatars.githubusercontent.com/u/67749770?v=4?s=100" width="70px" /><br />
        <sub><b>Anas</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/moazelsawaf">
        <img src="https://avatars.githubusercontent.com/u/43591891?v=4?s=100" width="70px" /><br />
        <sub><b>Moaz</b></sub>
      </a>
    </td>
  </tr>
  <tr>
    <td align="center">
      <a href="https://github.com/the-best-is-best">
        <img src="https://avatars.githubusercontent.com/u/72160249?v=4?s=100" width="70px" /><br />
        <sub><b>Michelle</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/Abdullah-Mohammed-Ali">
        <img src="https://avatars.githubusercontent.com/u/32640450?v=4?s=100" width="70px" /><br />
        <sub><b>Abdullah</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/ahmedsabahi">
        <img src="https://avatars.githubusercontent.com/u/41107620?v=4?s=100" width="70px" /><br />
        <sub><b>Ahmed</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/NourSabry">
        <img src="https://avatars.githubusercontent.com/u/77892673?v=4?s=100" width="70px" /><br />
        <sub><b>Nourhan</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/AnthonyXcode">
        <img src="https://avatars.githubusercontent.com/u/16952651?v=4?s=100" width="70px" /><br />
        <sub><b>Anthony</b></sub>
      </a>
    </td>
  </tr>
</table>

### How to Contribute

We welcome contributions from everyone\! Here's how you can help:

1.  **Report Issues**: Found a bug or have a feature request? [Open an issue](https://github.com/Abdelazeem777/requests_inspector/issues)
2.  **Submit Pull Requests**: Have a fix or improvement? We'd love to review your PR\!
3.  **Improve Documentation**: Help us make the docs clearer and more comprehensive
4.  **Share Feedback**: Let us know how you're using the package and what could be better

To add yourself as a contributor, simply follow the contribution guidelines and your efforts will be recognized here\!

---

## Roadmap

- [x] GraphQL support (adopted from upstream — see [Credits](#-credits--relationship-to-the-upstream-project)).
- [x] Server-Sent Events (SSE) logging.
- [x] `package:http` client support (`HttpInspectorClient`).
- [x] Search and filtering.
- [x] ~~HAR export (text and `.har` file)~~ — removed; sharing is now a single direct cURL+log format (see [Sharing & exporting requests](#sharing--exporting-requests)).
- [x] Inspector open/close callbacks.
- [x] `RequestMethod.QUERY`.
- [x] Automatic network file logging (`RequestsInspectorHttpOverrides`, "Files" tab).
- [ ] Firebase-backed logging/observability integration.
- [ ] A UI-level toggle for Stopper again (currently programmatic-only — see [Stopper](#6-stopper--intercept-requests--responses)).
- [ ] Additional HTTP client integrations.

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## 🎉 Thank you for using Requests Inspector!
