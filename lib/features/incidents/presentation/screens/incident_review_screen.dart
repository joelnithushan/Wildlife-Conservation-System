import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/providers.dart';
import '../providers/incident_providers.dart';
import '../widgets/uc02_widgets.dart';

/// UC02-S01 – Screen 4: Review report before submission.
///
/// Shows every captured detail. Missing required data is highlighted and the
/// report cannot be submitted; entered data is never discarded.
class IncidentReviewScreen extends ConsumerWidget {
  const IncidentReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(incidentFormControllerProvider);
    final ranger = ref.watch(currentUserProvider);
    // Keep the autoDispose submission provider alive while the awaited
    // submit() is in flight (the screen is the active listener).
    ref.watch(incidentSubmissionProvider);
    final controller = ref.read(incidentFormControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
          title: const Text('Review Incident'), leading: const BackButton()),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row(
            context,
            icon: Icons.category,
            label: 'Category',
            value: form.category?.label,
            missing: !form.categoryValid,
            onEdit: () => context.push(AppRoutes.newIncident),
          ),
          _row(
            context,
            icon: Icons.photo_camera,
            label: 'Evidence',
            value: form.evidence.hasPhoto
                ? 'Photo attached'
                : form.evidence.omissionReason,
            missing: !form.evidenceValid,
            onEdit: () => context.push(AppRoutes.incidentEvidence),
          ),
          _row(
            context,
            icon: Icons.location_on,
            label: 'Location',
            value: form.hasLocation
                ? '${form.latitude!.toStringAsFixed(5)}, '
                    '${form.longitude!.toStringAsFixed(5)} '
                    '(${form.locationSource == LocationSource.gps ? 'GPS' : 'Manual'})'
                : null,
            missing: !form.locationValid,
            onEdit: () => context.push(AppRoutes.incidentLocation),
          ),
          _row(
            context,
            icon: Icons.schedule,
            label: 'Observed',
            value: form.observedAt == null
                ? null
                : DateFormat('dd MMM yyyy, HH:mm').format(form.observedAt!),
            missing: false,
            onEdit: () => context.push(AppRoutes.incidentLocation),
          ),
          _row(
            context,
            icon: Icons.notes,
            label: 'Description',
            value: form.hasDescription ? form.description.trim() : null,
            missing: !form.descriptionValid,
            onEdit: () => context.push(AppRoutes.incidentLocation),
          ),
          if (form.evidence.evidence?.bytes != null)
            EvidencePreview(bytes: form.evidence.evidence!.bytes),
          _row(
            context,
            icon: Icons.my_location,
            label: 'Latitude',
            value: form.latitude?.toStringAsFixed(5),
            missing: form.latitude == null,
            onEdit: () => context.push(AppRoutes.incidentLocation),
          ),
          _row(
            context,
            icon: Icons.my_location,
            label: 'Longitude',
            value: form.longitude?.toStringAsFixed(5),
            missing: form.longitude == null,
            onEdit: () => context.push(AppRoutes.incidentLocation),
          ),
          _row(
            context,
            icon: Icons.access_time,
            label: 'Capture time',
            value: form.gpsCapturedAt == null
                ? null
                : DateFormat('dd MMM yyyy, HH:mm').format(form.gpsCapturedAt!),
            missing: form.gpsCapturedAt == null,
            onEdit: () => context.push(AppRoutes.incidentLocation),
          ),
          _row(
            context,
            icon: Icons.person,
            label: 'Ranger',
            value: ranger.name,
            missing: ranger.id.isEmpty,
            onEdit: () {},
          ),
          _row(
            context,
            icon: Icons.directions_walk,
            label: 'Patrol',
            value: form.patrolId,
            missing: !form.patrolValid,
            onEdit: () {},
          ),
          if (!form.readyToSubmit) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _missingText(form),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: PrimaryActionButton(
            label: 'Submit Incident',
            icon: Icons.send,
            onPressed: !form.readyToSubmit
                ? null
                : () => _submit(context, ref, controller),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    IncidentFormController controller,
  ) async {
    final submitted = await ref.read(incidentSubmissionProvider.notifier).submit();
    if (!context.mounted) return;
    final state = ref.read(incidentSubmissionProvider);
    if (submitted && state.reportId != null) {
      controller.reset();
      context.pushReplacement(AppRoutes.incidentResultFor(state.reportId!));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message ?? 'Submission failed.')),
      );
    }
  }

  String _missingText(IncidentFormState form) {
    final missing = <String>[
      if (!form.categoryValid) 'category',
      if (!form.evidenceValid) 'photo or omission reason',
      if (!form.locationValid) 'location',
      if (!form.descriptionValid) 'description',
    ];
    return 'Missing: ${missing.join(', ')}. The report cannot be submitted yet — '
        'your entries are kept.';
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String? value,
    required bool missing,
    required VoidCallback onEdit,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: missing ? AppColors.error : Colors.grey.shade300,
          width: missing ? 1.4 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(icon,
            color: missing ? AppColors.error : AppColors.primary),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: missing
            ? const Text('Missing – tap edit to fix',
                style: TextStyle(color: AppColors.error))
            : Text(value!, style: const TextStyle(color: AppColors.textPrimary)),
        trailing: IconButton(
          icon: const Icon(Icons.edit, size: 20),
          tooltip: 'Edit $label',
          onPressed: onEdit,
        ),
      ),
    );
  }
}
