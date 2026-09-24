import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/validators.dart';
import '../../application/patrol_tracking_controller.dart';

/// Screen 5 – Manual Waypoint. Records a [PatrolPosition] with captureMode =
/// manual (same model as GPS). Shown when there's no GPS fix, but always
/// available.
class ManualWaypointScreen extends ConsumerStatefulWidget {
  const ManualWaypointScreen({super.key, required this.patrolId});

  final String patrolId;

  @override
  ConsumerState<ManualWaypointScreen> createState() =>
      _ManualWaypointScreenState();
}

class _ManualWaypointScreenState extends ConsumerState<ManualWaypointScreen> {
  final _formKey = GlobalKey<FormState>();
  final _latController =
      TextEditingController(text: AppConstants.defaultLatitude.toString());
  final _lngController =
      TextEditingController(text: AppConstants.defaultLongitude.toString());
  bool _saving = false;

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final lat = double.parse(_latController.text.trim());
      final lng = double.parse(_lngController.text.trim());
      final controller = ref.read(patrolTrackingControllerProvider.notifier)
        ..attach(widget.patrolId);
      await controller.addManualWaypoint(lat, lng);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manual waypoint saved.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save waypoint: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateCoord(String? value, {required bool isLat}) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Enter a valid number';
    final ok = isLat
        ? Validators.validCoordinates(parsed, 0)
        : Validators.validCoordinates(0, parsed);
    if (!ok) return isLat ? 'Latitude -90..90' : 'Longitude -180..180';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Waypoint')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'No GPS fix. You can mark the location manually below.'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _latController,
              decoration: const InputDecoration(labelText: 'Latitude'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
              ],
              validator: (v) => _validateCoord(v, isLat: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lngController,
              decoration: const InputDecoration(labelText: 'Longitude'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
              ],
              validator: (v) => _validateCoord(v, isLat: false),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    title: const Text('Capture mode'),
                    trailing: const Text('Manual',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    dense: true,
                    title: const Text('Time'),
                    trailing: Text(DateFormat('HH:mm').format(DateTime.now()),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Save Waypoint'),
            ),
          ],
        ),
      ),
    );
  }
}
