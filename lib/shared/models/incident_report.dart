import 'package:equatable/equatable.dart';

import '../../core/enums/app_enums.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/serialization.dart';
import '../../core/utils/validators.dart';

/// A wildlife/poaching incident report (UC02), offline-capable.
class IncidentReport extends Equatable {
  const IncidentReport({
    required this.id,
    required this.rangerId,
    required this.parkId,
    required this.category,
    required this.description,
    required this.observedAt,
    required this.latitude,
    required this.longitude,
    required this.locationSource,
    required this.createdAt,
    this.patrolId,
    this.localPhotoPath,
    this.photoUrl,
    this.evidenceOmissionReason,
    this.submissionStatus = SubmissionStatus.draft,
    this.reviewStatus = ReviewStatus.pendingReview,
    this.reviewerId,
    this.reviewNotes,
    this.reviewedAt,
    this.syncState = SyncState.pending,
  });

  /// Creates a new draft incident with a stable client-generated ID.
  factory IncidentReport.create({
    required String rangerId,
    required String parkId,
    required IncidentCategory category,
    required String description,
    required DateTime observedAt,
    required double latitude,
    required double longitude,
    required LocationSource locationSource,
    required DateTime createdAt,
    String? patrolId,
    String? localPhotoPath,
  }) =>
      IncidentReport(
        id: IdGenerator.newId('incident'),
        rangerId: rangerId,
        parkId: parkId,
        category: category,
        description: description,
        observedAt: observedAt,
        latitude: latitude,
        longitude: longitude,
        locationSource: locationSource,
        createdAt: createdAt,
        patrolId: patrolId,
        localPhotoPath: localPhotoPath,
      );

  final String id;
  final String rangerId;
  final String? patrolId;
  final String parkId;
  final IncidentCategory category;
  final String description;
  final DateTime observedAt;
  final double latitude;
  final double longitude;
  final LocationSource locationSource;
  final String? localPhotoPath;
  final String? photoUrl;
  final String? evidenceOmissionReason;
  final SubmissionStatus submissionStatus;
  final ReviewStatus reviewStatus;
  final String? reviewerId;
  final String? reviewNotes;
  final DateTime? reviewedAt;
  final SyncState syncState;
  final DateTime createdAt;

  /// Business rule: a submitted incident must carry evidence or an omission
  /// reason. Drafts are always considered valid.
  bool get isEvidenceValid => Validators.incidentEvidenceValid(
        localPhotoPath: localPhotoPath,
        photoUrl: photoUrl,
        evidenceOmissionReason: evidenceOmissionReason,
      );

  bool get canSubmit => Validators.nonEmptyDescription(description) && isEvidenceValid;

  IncidentReport copyWith({
    String? rangerId,
    String? patrolId,
    String? parkId,
    IncidentCategory? category,
    String? description,
    DateTime? observedAt,
    double? latitude,
    double? longitude,
    LocationSource? locationSource,
    String? localPhotoPath,
    String? photoUrl,
    String? evidenceOmissionReason,
    SubmissionStatus? submissionStatus,
    ReviewStatus? reviewStatus,
    String? reviewerId,
    String? reviewNotes,
    DateTime? reviewedAt,
    SyncState? syncState,
    DateTime? createdAt,
  }) =>
      IncidentReport(
        id: id,
        rangerId: rangerId ?? this.rangerId,
        parkId: parkId ?? this.parkId,
        category: category ?? this.category,
        description: description ?? this.description,
        observedAt: observedAt ?? this.observedAt,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        locationSource: locationSource ?? this.locationSource,
        createdAt: createdAt ?? this.createdAt,
        patrolId: patrolId ?? this.patrolId,
        localPhotoPath: localPhotoPath ?? this.localPhotoPath,
        photoUrl: photoUrl ?? this.photoUrl,
        evidenceOmissionReason: evidenceOmissionReason ?? this.evidenceOmissionReason,
        submissionStatus: submissionStatus ?? this.submissionStatus,
        reviewStatus: reviewStatus ?? this.reviewStatus,
        reviewerId: reviewerId ?? this.reviewerId,
        reviewNotes: reviewNotes ?? this.reviewNotes,
        reviewedAt: reviewedAt ?? this.reviewedAt,
        syncState: syncState ?? this.syncState,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'rangerId': rangerId,
        'patrolId': patrolId,
        'parkId': parkId,
        'category': category.wire,
        'description': description,
        'observedAt': dateToWire(observedAt),
        'latitude': latitude,
        'longitude': longitude,
        'locationSource': locationSource.wire,
        'localPhotoPath': localPhotoPath,
        'photoUrl': photoUrl,
        'evidenceOmissionReason': evidenceOmissionReason,
        'submissionStatus': submissionStatus.wire,
        'reviewStatus': reviewStatus.wire,
        'reviewerId': reviewerId,
        'reviewNotes': reviewNotes,
        'reviewedAt': dateToWire(reviewedAt),
        'syncState': syncState.wire,
        'createdAt': dateToWire(createdAt),
      };

  factory IncidentReport.fromMap(Map<String, dynamic> map) => IncidentReport(
        id: map['id'] as String,
        rangerId: map['rangerId'] as String,
        patrolId: map['patrolId'] as String?,
        parkId: map['parkId'] as String,
        category: parseEnum(IncidentCategory.values, map['category'],
            fallback: IncidentCategory.other),
        description: map['description'] as String? ?? '',
        observedAt: dateFromWire(map['observedAt'])!,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        locationSource: parseEnum(LocationSource.values, map['locationSource'],
            fallback: LocationSource.gps),
        localPhotoPath: map['localPhotoPath'] as String?,
        photoUrl: map['photoUrl'] as String?,
        evidenceOmissionReason: map['evidenceOmissionReason'] as String?,
        submissionStatus: parseEnum(
            SubmissionStatus.values, map['submissionStatus'],
            fallback: SubmissionStatus.draft),
        reviewStatus: parseEnum(ReviewStatus.values, map['reviewStatus'],
            fallback: ReviewStatus.pendingReview),
        reviewerId: map['reviewerId'] as String?,
        reviewNotes: map['reviewNotes'] as String?,
        reviewedAt: dateFromWire(map['reviewedAt']),
        syncState:
            parseEnum(SyncState.values, map['syncState'], fallback: SyncState.pending),
        createdAt: dateFromWire(map['createdAt'])!,
      );

  @override
  List<Object?> get props => [
        id,
        rangerId,
        parkId,
        category,
        submissionStatus,
        reviewStatus,
        syncState,
      ];
}
