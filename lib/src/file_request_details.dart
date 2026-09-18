/// A lightweight record of a single non-API network file load (images,
/// videos, PDFs, fonts, downloads, ...), kept separate from [RequestDetails]
/// so this traffic doesn't crowd the "All" requests tab.
class FileRequestDetails {
  const FileRequestDetails({
    required this.url,
    required this.sentTime,
    this.statusCode,
    this.contentType,
    this.contentLength,
    this.receivedTime,
    this.error,
  });

  final String url;
  final int? statusCode;
  final String? contentType;
  final int? contentLength;
  final DateTime sentTime;
  final DateTime? receivedTime;
  final String? error;

  bool get isError =>
      error != null || (statusCode != null && statusCode! >= 400);
}
