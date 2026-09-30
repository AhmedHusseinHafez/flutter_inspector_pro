import '../enums/developer_log_level_enum.dart';
import 'developer_log_controller.dart';
import 'developer_log_entry.dart';

/// Public API for writing custom developer logs into the Inspector, where they
/// show up in the "All" timeline alongside HTTP/SSE/Firebase traffic.
///
/// ```dart
/// InspectorLogger.info('Checkout started', tag: 'Cart', data: {'items': 3});
///
/// try {
///   await pay();
/// } catch (e, s) {
///   InspectorLogger.error('Payment failed', tag: 'Cart', error: e, stackTrace: s);
/// }
/// ```
class InspectorLogger {
  InspectorLogger._();

  /// Master switch. When `false` every call is a no-op - handy for turning
  /// custom logging off in release builds with a single line.
  static bool enabled = true;

  static void log(
    String message, {
    DeveloperLogLevel level = DeveloperLogLevel.debug,
    String? tag,
    Object? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enabled) return;
    DeveloperLogController.log(DeveloperLogEntry(
      message: message,
      level: level,
      tag: tag,
      data: data,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  static void verbose(String message, {String? tag, Object? data}) =>
      log(message, level: DeveloperLogLevel.verbose, tag: tag, data: data);

  static void debug(String message, {String? tag, Object? data}) =>
      log(message, level: DeveloperLogLevel.debug, tag: tag, data: data);

  static void info(String message, {String? tag, Object? data}) =>
      log(message, level: DeveloperLogLevel.info, tag: tag, data: data);

  static void warning(
    String message, {
    String? tag,
    Object? data,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      log(
        message,
        level: DeveloperLogLevel.warning,
        tag: tag,
        data: data,
        error: error,
        stackTrace: stackTrace,
      );

  static void error(
    String message, {
    String? tag,
    Object? data,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      log(
        message,
        level: DeveloperLogLevel.error,
        tag: tag,
        data: data,
        error: error,
        stackTrace: stackTrace,
      );
}
