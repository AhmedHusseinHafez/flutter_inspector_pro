/// Severity of a [DeveloperLogEntry], from least to most severe.
enum DeveloperLogLevel {
  verbose('VERBOSE'),
  debug('DEBUG'),
  info('INFO'),
  warning('WARNING'),
  error('ERROR');

  const DeveloperLogLevel(this.label);

  /// Upper-case name shown on the level badge and in shared/exported logs.
  final String label;
}
