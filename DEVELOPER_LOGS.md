# Custom developer logs

`InspectorLogger` lets your own code write log lines into the Inspector:
user actions, state changes, cache hits and misses, caught exceptions, and so
on. They show up in the "All" timeline in time order next to the HTTP,
GraphQL, SSE and Firebase Messaging traffic, so you can see *what the app was
doing* around each request without switching to the console.

## Quick start

No setup is needed beyond the usual `RequestsInspector` wrapper. Import the
package and log:

```dart
import 'package:requests_inspector/requests_inspector.dart';

InspectorLogger.info('Checkout started');
```

Open the inspector and the entry is at the top of the "All" tab.

## Log levels

Pick a level with its shorthand method, or pass it explicitly to `log`:

| Method | Level | Typical use |
|---|---|---|
| `InspectorLogger.verbose(...)` | `DeveloperLogLevel.verbose` | Very noisy tracing |
| `InspectorLogger.debug(...)` | `DeveloperLogLevel.debug` | General debugging (the default for `log`) |
| `InspectorLogger.info(...)` | `DeveloperLogLevel.info` | Notable events: screen opened, user signed in |
| `InspectorLogger.warning(...)` | `DeveloperLogLevel.warning` | Something unexpected that the app recovered from |
| `InspectorLogger.error(...)` | `DeveloperLogLevel.error` | Failures and caught exceptions |

```dart
InspectorLogger.log('Token refreshed', level: DeveloperLogLevel.info);
```

Each level has its own badge color and icon in the timeline.

## Parameters

| Parameter | Type | Available on | Description |
|---|---|---|---|
| `message` | `String` | all | The log line. It's the entry's title in the timeline. |
| `tag` | `String?` | all | A short category such as `Auth` or `Cart`. It's shown next to the level, and search matches it. |
| `data` | `Object?` | all | A structured payload (`Map`, `List`, ...). The details page shows it as formatted JSON. |
| `error` | `Object?` | `log`, `warning`, `error` | The exception or error object. |
| `stackTrace` | `StackTrace?` | `log`, `warning`, `error` | The stack trace, shown in its own section. |
| `level` | `DeveloperLogLevel` | `log` only | Defaults to `debug`. |

## Examples

### Tags and data

```dart
InspectorLogger.debug(
  'Loaded posts screen',
  tag: 'Nav',
  data: {'route': '/posts', 'fromDeepLink': false},
);
```

### Logging caught exceptions

```dart
try {
  await paymentService.pay(order);
} catch (e, s) {
  InspectorLogger.error(
    'Payment failed',
    tag: 'Cart',
    error: e,
    stackTrace: s,
    data: {'orderId': order.id, 'amount': order.total},
  );
  rethrow;
}
```

### Tracing a flow around network calls

Because logs and requests share one timeline, you can bracket a flow and see
exactly which requests happened inside it:

```dart
InspectorLogger.info('Sync started', tag: 'Sync');
await api.fetchProfile();   // shows up as an HTTP entry
await api.fetchSettings();  // shows up as an HTTP entry
InspectorLogger.info('Sync finished', tag: 'Sync');
```

### Wrapping it in your own logger

If your app already has a logging facade, forward to `InspectorLogger` from
it so every existing log call shows up in the inspector:

```dart
class AppLog {
  static void i(String msg, {String? tag, Object? data}) {
    debugPrint('[$tag] $msg');
    InspectorLogger.info(msg, tag: tag, data: data);
  }

  static void e(String msg, Object error, StackTrace stack, {String? tag}) {
    debugPrint('[$tag] $msg: $error');
    InspectorLogger.error(msg, tag: tag, error: error, stackTrace: stack);
  }
}
```

## In the inspector

- **Timeline:** each entry shows the level badge, the message (up to two
  lines), `LEVEL · tag`, and the time.
- **Details page:** tap an entry to see its time, tag, message, data, error
  and stack trace. Each section has a copy button.
- **Share:** the share button on the details page sends the entry as plain
  text, ready to paste into Slack.
- **Filter:** in the filter dialog, choose **Logs** to show only developer
  logs.
- **Search:** the search bar matches a log's message and tag
  (case-insensitive), as well as request URLs.
- **Delete:** swipe an entry left to remove it. **Clear All** removes logs
  along with everything else.

## Saving logs to disk

Developer logs are one of the disk-persistence categories ("Custom developer
logs" in the storage dialog). Turn it on there, or from code:

```dart
RequestsInspector(
  logPersistence: const LogPersistenceConfig(
    defaultTypes: {PersistedLogType.developerLog},
  ),
  child: child,
)
```

Saved entries are written to `developer_logs.jsonl` and included in the
CSV/JSON export. In the export's columns:

| Column | Holds |
|---|---|
| `name` | The message |
| `method` | The level (`INFO`, `ERROR`, ...) |
| `url` | The tag |
| `error` | `error.toString()` |
| `details` | JSON with `data` and `stackTrace` (omitted when `includeBodies: false`) |

## Turning it off

```dart
// For example, in main() before runApp:
InspectorLogger.enabled = !kReleaseMode;
```

When `enabled` is `false`, every `InspectorLogger` call returns immediately.
Nothing is stored in memory or written to disk.

## Reading logs from code

`DeveloperLogController` is the store behind `InspectorLogger`:

```dart
// Newest first. It's a ValueListenable, so you can listen to it.
final entries = DeveloperLogController.entries.value;

DeveloperLogController.entries.addListener(() {
  final latest = DeveloperLogController.entries.value.first;
  // ...
});

DeveloperLogController.clear();
```

You can also build a `DeveloperLogEntry` yourself and pass it to
`DeveloperLogController.log(entry)`, for example to set a custom `time`.

## Limits and notes

- The last **500** entries are kept in memory; older ones are dropped.
- `data` is shown using the same JSON formatter as request bodies. Values that
  aren't JSON-friendly are shown with their `toString()`.
- Nothing is masked for you. Don't log secrets (tokens, passwords) in
  `message` or `data`, especially if you save logs to disk and share the
  exports.
