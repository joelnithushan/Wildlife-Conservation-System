import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../providers/evidence_providers.dart';
import '../providers/incident_providers.dart';
import '../widgets/uc02_widgets.dart';

/// UC02-S01 – Screen 2: Evidence.
///
/// Business rule: a submitted incident carries a photo OR a non-empty
/// evidence-omission reason (never both required, never neither).
class IncidentEvidenceScreen extends ConsumerStatefulWidget {
  const IncidentEvidenceScreen({super.key});

  @override
  ConsumerState<IncidentEvidenceScreen> createState() =>
      _IncidentEvidenceScreenState();
}

class _IncidentEvidenceScreenState
    extends ConsumerState<IncidentEvidenceScreen> {
  final _reasonController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Seed the field once from the draft (keeps text when navigating back);
    // afterwards the field owns the text and pushes changes to the controller.
    final existing =
        ref.read(incidentFormControllerProvider).evidence.omissionReason;
    if (existing != null) _reasonController.text = existing;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    setState(() => _busy = true);
    try {
      final evidence =
          await ref.read(incidentEvidenceSourceProvider).captureFromCamera();
      if (!mounted) return;
      if (evidence != null) {
        ref.read(incidentFormControllerProvider.notifier).setEvidence(evidence);
      }
    } catch (_) {
      if (!mounted) return;
      ref.read(incidentFormControllerProvider.notifier).setPhotoError(
            'Photo capture failed. Try again. Incident type, description, and GPS are kept.',
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() => _busy = true);
    try {
      final evidence =
          await ref.read(incidentEvidenceSourceProvider).pickFromGallery();
      if (!mounted) return;
      if (evidence != null) {
        ref.read(incidentFormControllerProvider.notifier).setEvidence(evidence);
      }
    } catch (_) {
      if (!mounted) return;
      ref.read(incidentFormControllerProvider.notifier).setPhotoError(
            'Could not open the photo. Try again. Your other incident details are kept.',
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(incidentFormControllerProvider);
    final evidence = form.evidence;

    return Scaffold(
      appBar: AppBar(
          title: const Text('Capture Photograph'), leading: const BackButton()),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionLabel('Photo evidence'),
          EvidencePreview(
            bytes: evidence.evidence?.bytes,
            onRetake: evidence.hasPhoto ? _capture : null,
          ),
          if (form.photoError != null) ...[
            const SizedBox(height: 8),
            Text(
              form.photoError!,
              key: const Key('photo-error'),
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _capture,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!evidence.hasPhoto) ...[
            const Center(
              child: Text(
                "Can't take a photo safely?",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            const SectionLabel('Reason for no photo'),
            TextField(
              controller: _reasonController,
              key: const Key('omission-reason-field'),
              decoration: const InputDecoration(
                hintText: 'e.g. Unsafe to approach the snare location.',
              ),
              minLines: 2,
              maxLines: 4,
              onChanged: ref
                  .read(incidentFormControllerProvider.notifier)
                  .setOmissionReason,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: PrimaryActionButton(
            label: 'Next',
            onPressed: !evidence.isValid
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Add a photo or a reason for taking none to continue.'),
                      ),
                    );
                  }
                : () => context.push(AppRoutes.incidentLocation),
          ),
        ),
      ),
    );
  }
}
