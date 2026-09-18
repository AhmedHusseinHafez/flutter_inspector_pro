import 'package:flutter/foundation.dart';

import 'image_request_details.dart';

/// A lightweight global log of network image loads, separate from
/// [RequestDetails]/[InspectorController] on purpose - image traffic tends
/// to be high-volume and isn't useful mixed into the main "All" timeline.
///
/// Populated automatically by [RequestsInspectorHttpOverrides] for every
/// image response observed anywhere in the app (no code changes required);
/// shown in the Inspector's "Images" tab.
class ImageLogController {
  ImageLogController._();

  static final ValueNotifier<List<ImageRequestDetails>> _images =
      ValueNotifier<List<ImageRequestDetails>>([]);

  static const int _maxEntries = 200;

  static ValueListenable<List<ImageRequestDetails>> get images => _images;

  static void log(ImageRequestDetails details) {
    final updated = [details, ..._images.value];
    if (updated.length > _maxEntries) {
      updated.removeRange(_maxEntries, updated.length);
    }
    _images.value = updated;
  }

  static void clear() => _images.value = [];
}
