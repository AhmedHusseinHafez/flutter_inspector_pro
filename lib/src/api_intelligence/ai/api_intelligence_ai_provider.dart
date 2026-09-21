/// Host-app-implemented AI interpretation layer for API Intelligence
/// (spec §22/§26). The package never bundles a vendor SDK or accepts a raw
/// API key - implement this to call your own backend/LLM proxy however you
/// like.
///
/// [sanitizedPayload] is the aggregated, already-sanitized analysis payload
/// (see `ApiIntelligencePayloadBuilder`) - sensitive headers/body fields are
/// already redacted before this is called.
///
/// The returned string is rendered as-is in the API Intelligence tab; the
/// package does not parse structure back out of it, so shape the response
/// however your model produces it (see spec §24 for a suggested report
/// template to prompt for).
abstract class ApiIntelligenceAiProvider {
  Future<String> generateReport(Map<String, dynamic> sanitizedPayload);
}
