import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/enums/app_enums.dart';
import '../../../shared/models/conservation_report.dart';
import '../domain/report_aggregator.dart';
import 'category_labels.dart';

/// Lines shared by the PDF. Built only from the already generated report.
List<String> describeReport(ConservationReport report) {
  final criteria = report.criteria;
  if (criteria == null) {
    throw const FormatException('Report snapshot has no criteria.');
  }
  final coverage = report.hasPatrolCoverage
      ? '${report.patrolCoverage.toStringAsFixed(1)}%'
      : 'N/A';
  final bucket = trendBucketFor(criteria.startDate, criteria.endDate);
  return [
    'Park Conservation Report',
    'Project: Smart Wildlife Conservation and Anti-Poaching Monitoring System',
    'Snapshot: ${report.snapshotId}',
    'Park: ${report.parkName.isEmpty ? criteria.parkId : report.parkName} (${criteria.parkId})',
    'Period: ${_iso(criteria.startDate)} to ${_iso(criteria.endDate)}',
    'Generated: ${_iso(report.generatedAt)}',
    'Data cutoff: ${_iso(report.dataCutoff)}',
    'Excluded pending field records: ${report.excludedPendingCount}',
    'Total incidents: ${report.totalIncidents}',
    for (final category in criteria.categories)
      '${incidentCategoryLabel(category)}: ${report.incidentCounts[category] ?? 0}',
    'Patrol coverage: $coverage',
    'Completed patrols in average: ${report.completedPatrolCount}',
    'Conflict alerts: ${report.totalConflictAlerts}',
    'Open conflict alerts: ${report.openAlertCount}',
    'Resolved conflict alerts: ${report.resolvedAlertCount}',
    'Conflict trend (${bucket == TrendBucket.month ? 'monthly' : 'weekly'}):',
    if (report.conflictTrends.isEmpty) 'No conflict alerts in this period.',
    for (final point in report.conflictTrends)
      '${_iso(point.periodStart)}: ${point.count}',
  ];
}

/// CSV sections for metadata, incident counts, patrol coverage, and trends.
/// Uses the same generated report. Does not query or recalculate.
String buildReportCsv(ConservationReport report) {
  final criteria = report.criteria;
  if (criteria == null) {
    throw const FormatException('Report snapshot has no criteria.');
  }
  final coverage = report.hasPatrolCoverage
      ? report.patrolCoverage.toStringAsFixed(1)
      : 'N/A';
  final rows = <List<String>>[
    ['section', 'field', 'value'],
    ['metadata', 'title', 'Park Conservation Report'],
    ['metadata', 'snapshotId', report.snapshotId],
    ['metadata', 'parkId', criteria.parkId],
    ['metadata', 'parkName', report.parkName],
    ['metadata', 'startDate', _iso(criteria.startDate)],
    ['metadata', 'endDate', _iso(criteria.endDate)],
    ['metadata', 'generatedAt', _iso(report.generatedAt)],
    ['metadata', 'dataCutoff', _iso(report.dataCutoff)],
    [
      'metadata',
      'excludedPendingCount',
      '${report.excludedPendingCount}',
    ],
    ['incidents', 'total', '${report.totalIncidents}'],
    for (final category in criteria.categories)
      [
        'incidents',
        category.wire,
        '${report.incidentCounts[category] ?? 0}',
      ],
    ['patrol', 'coveragePercent', coverage],
    ['patrol', 'completedPatrolCount', '${report.completedPatrolCount}'],
    ['conflict', 'total', '${report.totalConflictAlerts}'],
    ['conflict', 'open', '${report.openAlertCount}'],
    ['conflict', 'resolved', '${report.resolvedAlertCount}'],
    for (final point in report.conflictTrends)
      ['trend', _iso(point.periodStart), '${point.count}'],
  ];
  return const ListToCsvConverter().convert(rows);
}

Future<Uint8List> buildReportPdfBytes(ConservationReport report) async {
  final lines = describeReport(report);
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(level: 0, text: lines.first),
        pw.SizedBox(height: 8),
        for (final line in lines.skip(1))
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(line),
          ),
      ],
    ),
  );
  return document.save();
}

String _iso(DateTime value) => value.toUtc().toIso8601String();
