import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/models/wildlife_risk_alert.dart';
import 'status_chip.dart';

/// A single risk alert row in the Risk Alerts list.
class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.alert,
    required this.zoneName,
    this.animalCode,
    this.onTap,
  });

  final WildlifeRiskAlert alert;
  final String zoneName;
  final String? animalCode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('MMM d, HH:mm').format(alert.createdAt.toLocal());
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$zoneName • ${ConflictLabels.severity(alert.severity)} risk',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AlertStatusChip(alert.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(ConflictLabels.sourceIcon(alert.source),
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    ConflictLabels.source(alert.source),
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  if (animalCode != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.pets, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      animalCode!,
                      style:
                          TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    time,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
