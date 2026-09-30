import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../shared/models/incident_report.dart';

/// Converts between the shared [IncidentReport] model and Drift rows for the
/// `incident_reports` table. Mirrors the patrol feature's mapper conventions.
extension IncidentRowMapper on IncidentReportsTableData {
  IncidentReport toDomain() => IncidentReport(
        id: id,
        rangerId: rangerId,
        patrolId: patrolId,
        parkId: parkId,
        category: parseEnum(IncidentCategory.values, category,
            fallback: IncidentCategory.other),
        description: description,
        observedAt: observedAt,
        latitude: latitude,
        longitude: longitude,
        locationSource: parseEnum(
            LocationSource.values, locationSource,
            fallback: LocationSource.gps),
        localPhotoPath: localPhotoPath,
        photoUrl: photoUrl,
        evidenceOmissionReason: evidenceOmissionReason,
        submissionStatus: parseEnum(
            SubmissionStatus.values, submissionStatus,
            fallback: SubmissionStatus.draft),
        reviewStatus: parseEnum(ReviewStatus.values, reviewStatus,
            fallback: ReviewStatus.pendingReview),
        reviewerId: reviewerId,
        reviewNotes: reviewNotes,
        reviewedAt: reviewedAt,
        syncState: parseEnum(SyncState.values, syncState,
            fallback: SyncState.pending),
        createdAt: createdAt,
      );
}

extension IncidentCompanionMapper on IncidentReport {
  IncidentReportsTableCompanion toCompanion({DateTime? updatedAt}) =>
      IncidentReportsTableCompanion(
        id: Value(id),
        rangerId: Value(rangerId),
        patrolId: patrolId == null ? const Value.absent() : Value(patrolId!),
        parkId: Value(parkId),
        category: Value(category.wire),
        description: Value(description),
        observedAt: Value(observedAt),
        latitude: Value(latitude),
        longitude: Value(longitude),
        locationSource: Value(locationSource.wire),
        localPhotoPath:
            localPhotoPath == null ? const Value.absent() : Value(localPhotoPath!),
        photoUrl: photoUrl == null ? const Value.absent() : Value(photoUrl!),
        evidenceOmissionReason: evidenceOmissionReason == null
            ? const Value.absent()
            : Value(evidenceOmissionReason!),
        submissionStatus: Value(submissionStatus.wire),
        reviewStatus: Value(reviewStatus.wire),
        reviewerId:
            reviewerId == null ? const Value.absent() : Value(reviewerId!),
        reviewNotes:
            reviewNotes == null ? const Value.absent() : Value(reviewNotes!),
        reviewedAt:
            reviewedAt == null ? const Value.absent() : Value(reviewedAt!),
        syncState: Value(syncState.wire),
        createdAt: Value(createdAt),
        updatedAt: updatedAt == null ? const Value.absent() : Value(updatedAt),
      );
}
