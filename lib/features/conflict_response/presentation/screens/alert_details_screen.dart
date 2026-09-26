import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/wildlife_risk_alert.dart';
import '../../../../shared/session/current_user.dart';
import '../providers/conflict_providers.dart';
import '../widgets/status_chip.dart';

/// Screen 2 — Alert Details. Full alert context plus the correct primary action
/// for the current lifecycle stage.
class AlertDetailsScreen extends ConsumerWidget {
  const AlertDetailsScreen({super.key, required this.alertId});
  final String alertId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertAsync = ref.watch(alertProvider(alertId));
    final parkId = ref.watch(currentUserProvider).parkId;
    final zones = ref.watch(riskZonesProvider(parkId)).asData?.value ?? const [];
    final animals = ref.watch(trackedAnimalsProvider).asData?.value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Alert Details')),
      body: alertAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (alert) {
          if (alert == null) {
            return const Center(child: Text('Alert not found.'));
          }
          final zoneName = zones
                  .where((z) => z.id == alert.riskZoneId)
                  .map((z) => z.name)
                  .firstOrNull ??
              alert.riskZoneId ??
              'Unknown zone';
          final animalCode = animals
                  .where((a) => a.id == alert.animalId)
                  .map((a) => a.code)
                  .firstOrNull ??
              (alert.animalId ?? 'N/A');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      zoneName,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                  ),
                  AlertStatusChip(alert.status),
                ],
              ),
              const SizedBox(height: 16),
              _DetailCard(children: [
                _row('Alert ID', alert.id),
                _row('Source', ConflictLabels.source(alert.source)),
                _row('Animal', animalCode),
                _row('Risk zone', zoneName),
                _row('Severity', ConflictLabels.severity(alert.severity)),
                _row('Location',
                    '${alert.latitude.toStringAsFixed(4)}, ${alert.longitude.toStringAsFixed(4)}'),
                _row('Created',
                    DateFormat('MMM d, HH:mm').format(alert.createdAt.toLocal())),
                if (alert.resolvedAt != null)
                  _row(
                      'Resolved',
                      DateFormat('MMM d, HH:mm')
                          .format(alert.resolvedAt!.toLocal())),
              ]),
              const SizedBox(height: 12),
              _MapPlaceholder(
                  latitude: alert.latitude, longitude: alert.longitude),
              const SizedBox(height: 20),
              _actions(context, alert),
            ],
          );
        },
      ),
    );
  }

  Widget _actions(BuildContext context, WildlifeRiskAlert alert) {
    switch (alert.status) {
      case AlertStatus.newAlert:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () =>
                context.push(AppRoutes.assignResponderFor(alert.id)),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Assign Responder'),
          ),
        );
      case AlertStatus.resolved:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () =>
                context.push(AppRoutes.responseTrackingFor(alert.id)),
            icon: const Icon(Icons.history),
            label: const Text('View resolved history'),
          ),
        );
      default:
        // assigned / acknowledged / in progress → tracking + responder view
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    context.push(AppRoutes.responseTrackingFor(alert.id)),
                icon: const Icon(Icons.timeline),
                label: const Text('Response Tracking'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push(AppRoutes.responderAssignmentFor(alert.id)),
                icon: const Icon(Icons.phone_iphone),
                label: const Text('Open responder view'),
              ),
            ),
          ],
        );
    }
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      );
}

/// Lightweight location visual (avoids Google Maps API-key configuration for a
/// university project) — a clear coordinate card the manager/responder can read.
class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.place, color: AppColors.primary, size: 32),
            const SizedBox(height: 6),
            Text(
              '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
