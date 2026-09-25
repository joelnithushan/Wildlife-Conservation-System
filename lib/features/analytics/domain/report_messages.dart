/// User-facing copy for UC04. Kept in one place so UI and tests match.
abstract final class ReportMessages {
  static const missingPark = 'Select a park.';
  static const unauthorizedPark =
      'You are not permitted to report on this park.';
  static const missingStart = 'Select a start date.';
  static const missingEnd = 'Select an end date.';
  static const invalidRange = 'Start date must be on or before the end date.';
  static const missingCategories = 'Select at least one incident category.';
  static const generating = 'Creating a snapshot of synchronized records…';
  static const empty = 'No records for these filters.';
  static const serviceUnavailable =
      'The data service is unavailable – no new report was created.';
  static const exportSameSnapshot =
      'Export the same report shown on screen – same snapshot, filters and cutoff.';
  static const exportBeforeReport = 'Generate a report before exporting.';
  static const pdfFailed =
      'Could not create the PDF. The report on screen was not changed.';
  static const csvFailed =
      'Could not create the CSV. The report on screen was not changed.';
  static const accessDenied =
      'Conservation reports are available to Park Managers and Conservation Researchers.';
  static const synchronizedOnly =
      'Only synchronized field records are included in these totals.';

  static String pendingExcluded(int count) =>
      '$count pending field records excluded';
}
