import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../shared/models/location_reading.dart';
import '../../../../shared/demo/demo_data.dart';
import '../providers/conflict_providers.dart';

class ConflictResponseScreen extends ConsumerWidget {
  const ConflictResponseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider(DemoData.parkId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Risk Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(alertsProvider(DemoData.parkId)),
          ),
        ],
      ),
      body: alertsAsync.when(
        data: (alerts) {
          if (alerts.isEmpty) {
            return const Center(child: Text('No active alerts'));
          }
          return ListView.builder(
            itemCount: alerts.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return Card(
                child: ListTile(
                  title: Text('${alert.source.name} Alert'),
                  subtitle: Text('Status: ${alert.status.name}\nZone: ${alert.riskZoneId}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to details (implement routing or dialog)
                    showDialog(
                      context: context, 
                      builder: (c) => AlertDialog(
                        title: Text('Alert Details'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${alert.id}'),
                            Text('Status: ${alert.status.name}'),
                            const SizedBox(height: 16),
                            if (alert.status == AlertStatus.newAlert)
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(c);
                                  await ref.read(conflictControllerProvider.notifier).assignResponder(
                                    alertId: alert.id,
                                    responderId: DemoData.rangerPerera.id,
                                  );
                                },
                                child: const Text('Assign Responder (Ranger)'),
                              ),
                            if (alert.status == AlertStatus.assigned)
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(c);
                                  // Simulate getting assignment for this alert
                                  // For demo, we just assume we have the assignment ID or we find it
                                  // In real app, we'd query assignments by alertId
                                },
                                child: const Text('View Assignment'),
                              ),
                          ],
                        ),
                      )
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
            final reading = LocationReading.create(
              animalId: DemoData.trackedAnimals.first.id,
              latitude: 8.0,
              longitude: 80.8,
              observedAt: DateTime.now(),
              receivedAt: DateTime.now(),
            );
            ref.read(conflictControllerProvider.notifier).simulateReading(reading);
        },
        icon: const Icon(Icons.sensors),
        label: const Text('Simulate Collar Reading'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}
