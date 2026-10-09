import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_map.dart';
import '../../../../shared/providers/providers.dart';
import '../../../incidents/presentation/widgets/cached_park_map.dart';
import '../providers/conflict_providers.dart';
import '../widgets/status_chip.dart';

/// Community Member – Report Wildlife Conflict Screen.
/// Allows public/community members to report human-wildlife conflicts or sightings
/// with description, interactive map location, auto-captured time, and channel 'APP'.
/// Includes a "Simulate SMS report" demo action (channel 'SMS').
class ReportConflictScreen extends ConsumerStatefulWidget {
  const ReportConflictScreen({super.key});

  @override
  ConsumerState<ReportConflictScreen> createState() =>
      _ReportConflictScreenState();
}

class _ReportConflictScreenState extends ConsumerState<ReportConflictScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  double _latitude = 8.035;
  double _longitude = 80.910;
  final DateTime _autoTime = DateTime.now();
  bool _submitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport({required String channel}) async {
    if (channel == 'APP' && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);
    final description = channel == 'SMS'
        ? (_descriptionController.text.trim().isNotEmpty
            ? 'SMS: ${_descriptionController.text.trim()}'
            : 'SMS [Community Alert]: Wild elephant sighted entering farmland boundary near Minneriya village.')
        : _descriptionController.text.trim();

    try {
      final report = await ref
          .read(conflictControllerProvider.notifier)
          .submitCommunityReport(
            parkId: 'PARK-MIN',
            description: description,
            latitude: _latitude,
            longitude: _longitude,
            channel: channel,
          );

      if (!mounted) return;
      setState(() => _submitting = false);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle,
              color: AppColors.success, size: 48),
          title: Text(channel == 'SMS'
              ? 'SMS Report Received'
              : 'Conflict Report Submitted'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                channel == 'SMS'
                    ? 'Simulated SMS report logged successfully into UC03 conflict registry.'
                    : 'Thank you for your report. Wildlife Liaison Officers and Park Managers have received this sighting.',
              ),
              const SizedBox(height: 12),
              StatusChip(
                label: 'Channel: $channel',
                color: channel == 'APP' ? AppColors.success : AppColors.warning,
                icon: channel == 'APP' ? Icons.phone_android : Icons.sms,
              ),
              const SizedBox(height: 6),
              StatusChip(
                label: 'ID: ${report.id}',
                color: AppColors.primary,
                icon: Icons.tag,
              ),
              const SizedBox(height: 6),
              StatusChip(
                label: 'Time: ${DateFormat('HH:mm:ss').format(report.createdAt)}',
                color: AppColors.success,
                icon: Icons.access_time,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (channel == 'APP') {
                  _descriptionController.clear();
                }
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('MMM d, yyyy · HH:mm:ss').format(_autoTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Wildlife Conflict'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Top information card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            color: AppColors.primary, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Community Conflict Reporting',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Report animal sightings or conflicts near your village or farmland. Reports are reviewed by Community Liaison Officers (CLOs) to coordinate park responses.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        const StatusChip(
                          label: 'Channel: APP',
                          color: AppColors.success,
                          icon: Icons.phone_android,
                        ),
                        StatusChip(
                          label: 'Park: Minneriya (PARK-MIN)',
                          color: AppColors.primary,
                          icon: Icons.park,
                        ),
                        StatusChip(
                          label: 'Auto-Time: $timeStr',
                          color: AppColors.success,
                          icon: Icons.access_time,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Incident Description *',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText:
                          'Describe what you saw (e.g., single elephant damaged boundary fence near village road, no injuries)...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please provide a brief description of the conflict or sighting.';
                      }
                      if (v.trim().length < 5) {
                        return 'Description must be at least 5 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Map Location Picker
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Conflict Location *',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      StatusChip(
                        label:
                            '${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}',
                        color: AppColors.success,
                        icon: Icons.pin_drop,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap or drag on the map below to pinpoint where the animal was sighted:',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    void onPoint(({double latitude, double longitude}) pos) {
                      setState(() {
                        _latitude = pos.latitude;
                        _longitude = pos.longitude;
                      });
                    }

                    return ref.watch(mapsEnabledProvider)
                        ? GoogleLocationPicker(
                            height: 220,
                            latitude: _latitude,
                            longitude: _longitude,
                            onChanged: onPoint)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedParkMap(
                              height: 220,
                              latitude: _latitude,
                              longitude: _longitude,
                              onChanged: onPoint,
                            ),
                          );
                  }),
                  const SizedBox(height: 24),

                  // Submit Actions
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => _submitReport(channel: 'APP'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.send),
                      label: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Submit Conflict Report (APP)',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Demo Action: Simulate SMS report
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.sms_outlined,
                                color: AppColors.warning, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Demo Testing: SMS Ingestion',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Test the SMS channel workflow (channel: SMS) for community members without internet connectivity:',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade800),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _submitting
                              ? null
                              : () => _submitReport(channel: 'SMS'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.warning,
                            side: const BorderSide(color: AppColors.warning),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.cell_tower, size: 18),
                          label: const Text('Simulate SMS Report (Demo)'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
