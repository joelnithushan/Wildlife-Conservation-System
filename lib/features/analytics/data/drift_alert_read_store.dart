import '../../../core/database/app_database.dart';
import '../../../shared/models/wildlife_risk_alert.dart';
import '../../conflict_response/data/mappers/conflict_mappers.dart';
import 'report_read_store.dart';

/// Reads alerts from Drift (UC03 local persistence) for analytics snapshots.
class DriftAlertReadStore implements AlertReadStore {
  const DriftAlertReadStore(this._db);

  final AppDatabase _db;

  @override
  Future<List<WildlifeRiskAlert>> load(String parkId) async {
    final rows = await (_db.select(_db.wildlifeRiskAlertsTable)
          ..where((table) => table.parkId.equals(parkId)))
        .get();
    return rows.map((r) => r.toDomain()).toList();
  }
}
