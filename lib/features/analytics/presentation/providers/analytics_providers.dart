import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/repositories/report_export_service.dart';
import '../../../../shared/repositories/report_repository.dart';
import '../../data/drift_report_read_store.dart';
import '../../data/firestore_alert_read_store.dart';
import '../../data/report_export_service_impl.dart';
import '../../data/report_read_store.dart';
import '../../data/report_repository_impl.dart';

final reportReadStoreProvider = Provider<ReportReadStore>((ref) {
  final alerts = ref.watch(firebaseReadyProvider)
      ? FirestoreAlertReadStore()
      : const EmptyAlertReadStore();
  return DriftReportReadStore(
    ref.watch(appDatabaseProvider),
    alerts: alerts,
  );
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepositoryImpl(
    store: ref.watch(reportReadStoreProvider),
    currentUser: () => ref.read(currentUserProvider),
  );
});

final reportExportServiceProvider = Provider<ReportExportService>(
  (ref) => ReportExportServiceImpl(),
);
