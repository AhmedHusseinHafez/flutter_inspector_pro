/// The file formats saved logs can be exported to.
enum LogExportFormat {
  /// One row per log entry, with a fixed set of columns - opens directly in
  /// Excel/Numbers/Sheets and stays small.
  csv('CSV', 'csv', 'text/csv'),

  /// The same entries as a JSON array, for feeding into a script instead of a
  /// spreadsheet.
  json('JSON', 'json', 'application/json');

  const LogExportFormat(this.label, this.extension, this.mimeType);

  final String label;
  final String extension;
  final String mimeType;
}
