/// Evidence that an endpoint may be returning a large, unpaginated
/// collection in a single response (spec §10).
class PaginationObservation {
  const PaginationObservation({
    required this.endpointLabel,
    required this.itemCount,
    required this.responseBytes,
    required this.hasPaginationMetadata,
    required this.paginationKeysFound,
  });

  final String endpointLabel;
  final int itemCount;
  final int responseBytes;

  /// Whether keys like page/limit/cursor/total/hasMore were found alongside
  /// the collection, suggesting the API already supports pagination even if
  /// this particular call returned everything.
  final bool hasPaginationMetadata;
  final List<String> paginationKeysFound;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'endpoint': endpointLabel,
        'itemCount': itemCount,
        'responseBytes': responseBytes,
        'hasPaginationMetadata': hasPaginationMetadata,
        'paginationKeysFound': paginationKeysFound,
      };
}
