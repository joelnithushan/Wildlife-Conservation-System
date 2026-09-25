import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../shared/models/wildlife_risk_alert.dart';
import '../../../../shared/models/location_reading.dart';
import '../../data/repositories/conflict_repository_impl.dart';

part 'conflict_providers.g.dart';

@riverpod
Stream<List<WildlifeRiskAlert>> alerts(AlertsRef ref, String parkId) async* {
  final repo = ref.watch(conflictRepositoryProvider);
  // Ideally use snapshots, but we can mock with a periodic poll for simplicity if stream is hard
  // For demo, we use a simple loop or just fetch once and rely on ref.invalidate
  while (true) {
    yield await repo.getAlerts(parkId);
    await Future.delayed(const Duration(seconds: 2));
  }
}

@riverpod
class ConflictController extends _$ConflictController {
  @override
  FutureOr<void> build() {}

  Future<void> simulateReading(LocationReading reading) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(conflictRepositoryProvider);
      await repo.processLocationReading(reading);
    });
  }
  
  Future<void> assignResponder({required String alertId, required String responderId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(conflictRepositoryProvider);
      await repo.assignResponder(alertId: alertId, responderId: responderId, assignedBy: 'PM001');
    });
  }
}
