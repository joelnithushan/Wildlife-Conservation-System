import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/session/current_user.dart';
import '../providers/conflict_providers.dart';
import '../widgets/responder_tile.dart';

/// Screen 3 — Assign Responder. Only available responders are selectable; the
/// manager picks one and assigns, which creates a [ResponseAssignment] and fires
/// a notification. Handles the no-responder and assignment-conflict cases.
class AssignResponderScreen extends ConsumerStatefulWidget {
  const AssignResponderScreen({super.key, required this.alertId});
  final String alertId;

  @override
  ConsumerState<AssignResponderScreen> createState() =>
      _AssignResponderScreenState();
}

class _AssignResponderScreenState extends ConsumerState<AssignResponderScreen> {
  String? _selectedId;
  bool _busy = false;

  Future<void> _assign() async {
    final id = _selectedId;
    if (id == null) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(conflictControllerProvider.notifier).assignResponder(
            alertId: widget.alertId,
            responderId: id,
          );
      messenger.showSnackBar(const SnackBar(
        content: Text('Responder assigned. Notification sent.'),
      ));
      navigator.pop();
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(
        content: Text('$e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final parkId = ref.watch(currentUserProvider).parkId;
    final respondersAsync = ref.watch(availableRespondersProvider(parkId));

    return Scaffold(
      appBar: AppBar(title: const Text('Assign Responder')),
      body: respondersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (responders) {
          if (responders.isEmpty) {
            return const _NoResponders();
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      child: Text(
                        'Available responders',
                        style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    for (final r in responders)
                      ResponderTile(
                        responder: r,
                        selected: _selectedId == r.id,
                        onTap: () => setState(() => _selectedId = r.id),
                      ),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          (_selectedId == null || _busy) ? null : _assign,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : const Text('Assign & Notify'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NoResponders extends StatelessWidget {
  const _NoResponders();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined,
                size: 48, color: AppColors.warning),
            const SizedBox(height: 12),
            const Text(
              'No responder available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'The alert stays NEW until a responder becomes available.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
