import 'package:flutter/foundation.dart';

import 'file_request_details.dart';

/// A lightweight global log of network file loads (images, videos, PDFs,
/// fonts, downloads, ...), separate from [RequestDetails]/[InspectorController]
/// on purpose - this traffic tends to be high-volume and isn't useful mixed
/// into the main "All" timeline.
///
/// Populated automatically by [RequestsInspectorHttpOverrides] for every
/// response observed anywhere in the app (no code changes required); shown
/// in the Inspector's "Files" tab.
class FileLogController {
  FileLogController._();

  static final ValueNotifier<List<FileRequestDetails>> _files =
      ValueNotifier<List<FileRequestDetails>>([]);

  static const int _maxEntries = 200;

  static ValueListenable<List<FileRequestDetails>> get files => _files;

  static void log(FileRequestDetails details) {
    final updated = [details, ..._files.value];
    if (updated.length > _maxEntries) {
      updated.removeRange(_maxEntries, updated.length);
    }
    _files.value = updated;
  }

  static void clear() => _files.value = [];
}
