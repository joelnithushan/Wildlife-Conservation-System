import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_extensions.dart';
import '../../../../shared/models/incident_report.dart';
import '../../../../shared/providers/providers.dart';
import '../providers/incident_providers.dart';
import '../widgets/uc02_widgets.dart';

/// UC02 hub. For rangers: "my reports" with submission/sync status and the
/// New Report action. For the park manager: the entry point to the UC02-S02
/// review queue. Uses the existing `/incidents` route + bottom-nav tab.
class IncidentsScreen extends ConsumerWidget {
  const IncidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isManager = user.role == UserRole.parkManager;
    final pendingAsync = ref.watch(pendingIncidentsProvider);
    final isOnline = ref.watch(isOnlineProvider).value ?? true;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Wildlife Incidents'),
        actions: [
          if (isOnline)
            const Icon(Icons.wifi, color: AppColors.success)
          else
            const Icon(Icons.wifi_off, color: AppColors.warning),
          const SizedBox(width: 12),
          if (isManager)
            IconButton(
              tooltip: 'Incident review queue',
              icon: const Icon(Icons.fact_check),
              onPressed: () => context.push(AppRoutes.incidentReviewQueue),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newIncident),
        icon: const Icon(Icons.add),
        label: const Text('Report Incident'),
      ),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Could not load incidents.\n$e', textAlign: TextAlign.center),
        ),
        data: (pending) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!isOnline) ...[
              const OfflineSavedBanner(),
              const SizedBox(height: 12),
            ],
            Text(
              isManager
                  ? 'Reports pending sync on this device: ${pending.length}'
                  : 'My reports pending sync: ${pending.length}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (pending.isEmpty)
              const _EmptyReports()
            else
              ...pending.map(
                (report) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReportTile(report: report),
                ),
              ),
            if (isManager) ...[
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.fact_check, color: AppColors.primary),
                  title: const Text('Incident Review'),
                  subtitle: const Text(
                      'Review synchronized reports from all rangers'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.incidentReviewQueue),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});

  final IncidentReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          report.category.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('Observed ${report.observedAt.toDisplayDateTime()}'),
        trailing: syncStatusChip(report.syncState),
      ),
    );
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 8),
          const Text('No incidents recorded yet.'),
          const SizedBox(height: 4),
          Text(
            'Tap "Report Incident" to file your first report. '
            'It works fully offline.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
