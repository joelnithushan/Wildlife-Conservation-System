import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/models/patrol.dart';
import '../../../../shared/models/patrol_route.dart';
import 'patrol_status_chip.dart';

/// List card summarising a patrol (design: title + "RT-07 · 7.4 km · 06:30").
class PatrolCard extends StatelessWidget {
  const PatrolCard({
    super.key,
    required this.patrol,
    required this.route,
    this.onTap,
  });

  final Patrol patrol;
  final PatrolRoute? route;
  final VoidCallback? onTap;

  String get _subtitle {
    final parts = <String>[
      patrol.routeId,
      if (route != null) '${route!.distanceKm} km',
      DateFormat('HH:mm').format(patrol.scheduledFor),
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          route?.name ?? patrol.routeId,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_subtitle),
        ),
        trailing: PatrolStatusChip(patrol.status),
      ),
    );
  }
}
