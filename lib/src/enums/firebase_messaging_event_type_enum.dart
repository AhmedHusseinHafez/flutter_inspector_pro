/// Which Firebase Messaging callback produced a logged
/// [FirebaseMessagingEvent].
enum FirebaseMessagingEventType {
  onMessage,
  onMessageOpenedApp,
  onBackgroundMessage,
  initialMessage,
}

extension FirebaseMessagingEventTypeLabel on FirebaseMessagingEventType {
  /// Matches the real API name developers already know
  /// (`FirebaseMessaging.onMessage`, etc.) instead of a paraphrase.
  String get label {
    switch (this) {
      case FirebaseMessagingEventType.onMessage:
        return 'onMessage';
      case FirebaseMessagingEventType.onMessageOpenedApp:
        return 'onMessageOpenedApp';
      case FirebaseMessagingEventType.onBackgroundMessage:
        return 'onBackgroundMessage';
      case FirebaseMessagingEventType.initialMessage:
        return 'initialMessage';
    }
  }
}
