import 'package:firebase_messaging/firebase_messaging.dart';

import '../enums/firebase_messaging_event_type_enum.dart';
import '../helpers/fcm_data_parser.dart';
import '../json_pretty_converter.dart';
import 'firebase_messaging_inspector_config.dart';

/// A single logged Firebase Messaging event - one `onMessage`,
/// `onMessageOpenedApp`, `onBackgroundMessage` call, or the message returned
/// by `getInitialMessage()`.
///
/// Kept separate from [RequestDetails] (like SSE and image logs) since FCM
/// events aren't HTTP request/response pairs.
class FirebaseMessagingEvent {
  FirebaseMessagingEvent({
    required this.type,
    DateTime? receivedAt,
    this.messageId,
    this.senderId,
    this.from,
    this.sentTime,
    this.ttl,
    this.collapseKey,
    this.messageType,
    this.data,
    this.notificationTitle,
    this.notificationBody,
    this.android,
    this.apple,
  }) : receivedAt = receivedAt ?? DateTime.now() {
    _id = '${type.name}-${this.receivedAt.microsecondsSinceEpoch}';
  }

  late final String _id;
  String get id => _id;

  final FirebaseMessagingEventType type;
  final DateTime receivedAt;
  final String? messageId;
  final String? senderId;
  final String? from;
  final DateTime? sentTime;
  final int? ttl;
  final String? collapseKey;
  final String? messageType;
  final Map<String, dynamic>? data;
  final String? notificationTitle;
  final String? notificationBody;

  /// Android-specific notification fields (`AndroidNotification`), when the
  /// message carried one.
  final Map<String, dynamic>? android;

  /// APNs/Apple-specific notification fields (`AppleNotification`), when the
  /// message carried one.
  final Map<String, dynamic>? apple;

  bool get hasNotification =>
      notificationTitle != null || notificationBody != null;

  /// A short title for list rows: the notification title if there is one,
  /// otherwise the message id, otherwise the event type.
  String get displayTitle => notificationTitle ?? messageId ?? type.label;

  String? _dataPretty;
  String get dataPretty => _dataPretty ??= data != null
      ? JsonPrettyConverter().convert(FcmDataParser.normalize(data!))
      : '';

  String? _androidPretty;
  String get androidPretty => _androidPretty ??=
      android != null ? JsonPrettyConverter().convert(android) : '';

  String? _applePretty;
  String get applePretty => _applePretty ??=
      apple != null ? JsonPrettyConverter().convert(apple) : '';

  /// Builds an event from a raw [RemoteMessage], redacting any `data` keys
  /// matching [maskedDataKeys] (case-insensitive substring match).
  factory FirebaseMessagingEvent.fromRemoteMessage(
    RemoteMessage message,
    FirebaseMessagingEventType type, {
    Set<String> maskedDataKeys =
        FirebaseMessagingInspectorConfig.defaultMaskedDataKeys,
  }) {
    final notification = message.notification;

    return FirebaseMessagingEvent(
      type: type,
      messageId: message.messageId,
      senderId: message.senderId,
      from: message.from,
      sentTime: message.sentTime,
      ttl: message.ttl,
      collapseKey: message.collapseKey,
      messageType: message.messageType,
      data: _maskData(message.data, maskedDataKeys),
      notificationTitle: notification?.title,
      notificationBody: notification?.body,
      android: _androidMap(notification?.android),
      apple: _appleMap(notification?.apple),
    );
  }

  static Map<String, dynamic>? _maskData(
    Map<String, dynamic> data,
    Set<String> maskedKeys,
  ) {
    if (data.isEmpty) return null;
    if (maskedKeys.isEmpty) return data;

    return data.map((key, value) {
      final lowerKey = key.toLowerCase();
      final isMasked =
          maskedKeys.any((m) => lowerKey.contains(m.toLowerCase()));
      return MapEntry(key, isMasked ? '***' : value);
    });
  }

  static Map<String, dynamic>? _androidMap(AndroidNotification? android) {
    if (android == null) return null;
    return <String, dynamic>{
      if (android.channelId != null) 'channelId': android.channelId,
      if (android.clickAction != null) 'clickAction': android.clickAction,
      if (android.color != null) 'color': android.color,
      if (android.count != null) 'count': android.count,
      if (android.imageUrl != null) 'imageUrl': android.imageUrl,
      if (android.link != null) 'link': android.link,
      'priority': android.priority.toString(),
      if (android.smallIcon != null) 'smallIcon': android.smallIcon,
      if (android.sound != null) 'sound': android.sound,
      if (android.tag != null) 'tag': android.tag,
      if (android.ticker != null) 'ticker': android.ticker,
      'visibility': android.visibility.toString(),
    }..removeWhere((_, v) => v == null);
  }

  static Map<String, dynamic>? _appleMap(AppleNotification? apple) {
    if (apple == null) return null;
    return <String, dynamic>{
      if (apple.badge != null) 'badge': apple.badge,
      if (apple.subtitle != null) 'subtitle': apple.subtitle,
    }..removeWhere((_, v) => v == null);
  }
}
