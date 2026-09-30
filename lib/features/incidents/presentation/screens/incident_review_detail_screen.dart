import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/utils/date_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/incident_report.dart';
import '../providers/incident_providers.dart';
import '../widgets/uc02_widgets.dart';

/// UC02-S02 – Screen 8: Review one synchronized incident report.
///
/// Shows every detail (photo or omission reason, location + source,
/// description, current status) and lets the authorized reviewer set
/// underReview / verified / rejected with an optional note. On success the
/// reviewer id, timestamp, resulting status and note are recorded and the
/// reviewer returns to the queue.
class IncidentReviewDetailScreen extends ConsumerStatefulWidget {
  const IncidentReviewDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  ConsumerState<IncidentReviewDetailScreen> createState() =>
      _IncidentReviewDetailScreenState();
}

class _IncidentReviewDetailScreenState
    extends ConsumerState<IncidentReviewDetailScreen> {
  ReviewStatus? _selected;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(selectedIncidentProvider(widget.reportId));
    final saveState = ref.watch(reviewSaveProvider(widget.reportId));

    return Scaffold(
      appBar: AppBar(title: const Text('Review Incident')),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load the report: $e')),
        data: (report) {
          if (report == null) {
            return const Center(child: Text('Report not found.'));
          }
          final saving = saveState.saving;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Report ${report.id}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  reviewStatusChip(report.reviewStatus),
                ],
              ),
              const SizedBox(height: 12),
              _DetailCard(children: [
                _detail('Category', report.category.name),
                _detail('Observed',
                    DateFormat('dd MMM yyyy, HH:mm').format(report.observedAt)),
                _detail('Ranger', report.rangerId),
                if (report.patrolId != null)
                  _detail('Patrol', report.patrolId!),
                _detail(
                  'Location',
                  '${report.latitude.toStringAsFixed(5)}, '
                      '${report.longitude.toStringAsFixed(5)}',
                ),
                _detail(
                  'Location source',
                  report.locationSource == LocationSource.gps ? 'GPS' : 'Manual',
                ),
                _detail('Description', report.description),
                if (report.evidenceOmissionReason != null)
                  _detail('No photo because', report.evidenceOmissionReason!),
              ]),
              const SizedBox(height: 12),
              const SectionLabel('Photo evidence'),
              _EvidenceForReview(report: report),
              const SizedBox(height: 16),
              const SectionLabel('Review decision'),
              SegmentedButton<ReviewStatus>(
                segments: const [
                  ButtonSegment(
                    value: ReviewStatus.underReview,
                    icon: Icon(Icons.visibility),
                    label: Text('Under review'),
                  ),
                  ButtonSegment(
                    value: ReviewStatus.verified,
                    icon: Icon(Icons.check_circle),
                    label: Text('Verified'),
                  ),
                  ButtonSegment(
                    value: ReviewStatus.rejected,
                    icon: Icon(Icons.block),
                    label: Text('Rejected'),
                  ),
                ],
                selected: {
                  _selected ?? (report.reviewStatus == ReviewStatus.pendingReview
                      ? ReviewStatus.underReview
                      : report.reviewStatus)
                },
                onSelectionChanged: (selection) =>
                    setState(() => _selected = selection.first),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('review-note-field'),
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Review note (optional)',
                  hintText: 'e.g. Site inspected, snare removed.',
                ),
                minLines: 2,
                maxLines: 4,
              ),
              if (saveState.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  saveState.error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () => _save(report),
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: const Text('Save Review'),
              ),
              const SizedBox(height: 8),
              if (report.reviewerId != null)
                Text(
                  'Last review by ${report.reviewerId} at '
                  '${report.reviewedAt?.toDisplayDateTime() ?? '—'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save(IncidentReport report) async {
    final status = _selected ??
        (report.reviewStatus == ReviewStatus.pendingReview
            ? ReviewStatus.underReview
            : report.reviewStatus);
    await ref
        .read(reviewSaveProvider(widget.reportId).notifier)
        .save(
          status: status,
          // An empty note means "no note": don't store a blank string.
          reviewNotes: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
    if (!mounted) return;
    final state = ref.read(reviewSaveProvider(widget.reportId));
    if (state.saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review saved: ${status.name}.')),
      );
      // Return to the review queue with the updated status (deep-link safe).
      if (context.canPop()) context.pop();
    } else if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error!)),
      );
    }
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(14), child: Column(children: children)),
    );
  }
}

/// Shows the photo (local copy on the reviewer device, remote URL, or the
/// omission reason when the ranger could not photograph safely).
class _EvidenceForReview extends StatelessWidget {
  const _EvidenceForReview({required this.report});

  final IncidentReport report;

  @override
  Widget build(BuildContext context) {
    if (report.localPhotoPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(report.localPhotoPath!),
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _MissingFrame(
              text: 'Photo stored remotely – open the report online to view it.'),
        ),
      );
    }
    if (report.photoUrl != null) {
      return const _MissingFrame(text: 'Photo available at the recorded URL.');
    }
    if (report.evidenceOmissionReason != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.no_photography, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  'No photo – reason: ${report.evidenceOmissionReason}'),
            ),
          ],
        ),
      );
    }
    return const _MissingFrame(text: 'No evidence attached.');
  }
}

class _MissingFrame extends StatelessWidget {
  const _MissingFrame({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}
