/// The optimization category a finding belongs to (spec §20).
enum ApiIntelligenceCategory {
  performance,
  redundancy,
  caching,
  payload,
  pagination,
  reliability,
  http,
  waterfall,
  mobileSuitability,
}

extension ApiIntelligenceCategoryLabel on ApiIntelligenceCategory {
  String get label {
    switch (this) {
      case ApiIntelligenceCategory.performance:
        return 'Performance';
      case ApiIntelligenceCategory.redundancy:
        return 'Redundancy';
      case ApiIntelligenceCategory.caching:
        return 'Caching';
      case ApiIntelligenceCategory.payload:
        return 'Payload';
      case ApiIntelligenceCategory.pagination:
        return 'Pagination';
      case ApiIntelligenceCategory.reliability:
        return 'Reliability';
      case ApiIntelligenceCategory.http:
        return 'HTTP';
      case ApiIntelligenceCategory.waterfall:
        return 'Waterfall';
      case ApiIntelligenceCategory.mobileSuitability:
        return 'Mobile Suitability';
    }
  }
}

/// Investigation severity (spec §21). These are NOT quality scores - they
/// describe how much evidence exists and how urgent it is to look.
enum FindingSeverity {
  healthy,
  watch,
  optimizationCandidate,
  highPriorityInvestigation,
}

extension FindingSeverityLabel on FindingSeverity {
  String get label {
    switch (this) {
      case FindingSeverity.healthy:
        return 'Healthy';
      case FindingSeverity.watch:
        return 'Watch';
      case FindingSeverity.optimizationCandidate:
        return 'Optimization Candidate';
      case FindingSeverity.highPriorityInvestigation:
        return 'High Priority Investigation';
    }
  }
}

/// A single, evidence-backed observation produced by the deterministic
/// analyzer (spec §24 shape: Endpoint / Observation / Evidence / Potential
/// Impact / Suggested Investigation).
class ApiIntelligenceFinding {
  const ApiIntelligenceFinding({
    required this.category,
    required this.severity,
    required this.observation,
    required this.evidence,
    this.endpoint,
    this.potentialImpact,
    this.suggestedInvestigation,
  });

  final ApiIntelligenceCategory category;
  final FindingSeverity severity;

  /// A short label identifying the endpoint this finding is about (e.g.
  /// "GET /api/v1/investments"), or null for session-wide findings.
  final String? endpoint;

  final String observation;
  final List<String> evidence;
  final String? potentialImpact;
  final String? suggestedInvestigation;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'category': category.label,
        'severity': severity.label,
        if (endpoint != null) 'endpoint': endpoint,
        'observation': observation,
        'evidence': evidence,
        if (potentialImpact != null) 'potentialImpact': potentialImpact,
        if (suggestedInvestigation != null)
          'suggestedInvestigation': suggestedInvestigation,
      };
}
