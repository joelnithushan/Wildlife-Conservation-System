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
    final evidence =
        await ref.read(incidentEvidenceSourceProvider).captureFromCamera();
    if (!mounted) return;
    setState(() => _busy = false);
    if (evidence != null) {
      ref.read(incidentFormControllerProvider.notifier).setEvidence(evidence);
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() => _busy = true);
    final evidence =
        await ref.read(incidentEvidenceSourceProvider).pickFromGallery();
    if (!mounted) return;
    setState(() => _busy = false);
    if (evidence != null) {
      ref.read(incidentFormControllerProvider.notifier).setEvidence(evidence);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(incidentFormControllerProvider);
    final evidence = form.evidence;

    return Scaffold(
      appBar: AppBar(title: const Text('Evidence'), leading: const BackButton()),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionLabel('Photo evidence'),
          EvidencePreview(
            localPath: evidence.localPath,
            onRetake: evidence.hasPhoto ? _capture : null,
          ),
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
