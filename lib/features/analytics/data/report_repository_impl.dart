import '../../../core/errors/exceptions.dart';
import '../../../core/utils/id_generator.dart';
import '../../../shared/demo/demo_data.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/conservation_report.dart';
import '../../../shared/models/report_criteria.dart';
import '../../../shared/repositories/report_repository.dart';
import '../domain/report_access_policy.dart';
import '../domain/report_aggregator.dart';
import '../domain/report_messages.dart';
import 'report_read_store.dart';

/// UC04 report generation. Validates scope, reads once, aggregates, returns
/// a snapshot. It does not create or update patrols, incidents, or alerts.
class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl({
    required ReportReadStore store,
    required AppUser Function() currentUser,
    DateTime Function()? now,
    String Function()? newSnapshotId,
    String Function(String parkId)? parkName,
  })  : _store = store,
        _currentUser = currentUser,
        _now = now ?? DateTime.now,
        _newSnapshotId = newSnapshotId ?? (() => IdGenerator.newId('report')),
        _parkName = parkName ?? _defaultParkName;

  final ReportReadStore _store;
  final AppUser Function() _currentUser;
  final DateTime Function() _now;
  final String Function() _newSnapshotId;
  final String Function(String parkId) _parkName;

  static String _defaultParkName(String parkId) =>
      parkId == DemoData.park.id ? DemoData.park.name : parkId;

  @override
  Future<ConservationReport> generateReport(ReportCriteria criteria) async {
    final user = _currentUser();
    if (!ReportAccessPolicy.allows(user, criteria.parkId)) {
      throw const PermissionException(ReportMessages.unauthorizedPark);
    }
    if (!criteria.isValid) {
      throw const ValidationException(ReportMessages.invalidRange);
    }
    if (criteria.categories.isEmpty) {
      throw const ValidationException(ReportMessages.missingCategories);
    }

    final source = await _store.load(criteria.parkId);
    final generatedAt = _now().toUtc();
    return ReportAggregator.aggregate(
      criteria: criteria,
      parkName: _parkName(criteria.parkId),
      source: source,
      generatedAt: generatedAt,
      snapshotId: _newSnapshotId(),
    );
  }
}
