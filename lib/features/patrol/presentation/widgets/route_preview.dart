import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/geo_coordinate.dart';
import '../../../../shared/models/patrol_position.dart';

/// Lightweight map-free route preview.
///
/// Plots the planned path (line) and recorded positions (dots) on a normalized
/// canvas. Used instead of a live map so the app runs without a Google Maps API
/// key; `google_maps_flutter` can replace this later without touching callers.
class RoutePreview extends StatelessWidget {
  const RoutePreview({
    super.key,
    required this.plannedPath,
    this.positions = const [],
    this.height = 180,
  });

  final List<GeoCoordinate> plannedPath;
  final List<PatrolPosition> positions;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEDF2EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: plannedPath.isEmpty && positions.isEmpty
          ? const Center(
              child: Text('No route data', style: TextStyle(color: Colors.grey)),
            )
          : CustomPaint(
              painter: _RoutePainter(plannedPath: plannedPath, positions: positions),
            ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.plannedPath, required this.positions});

  final List<GeoCoordinate> plannedPath;
  final List<PatrolPosition> positions;

  @override
  void paint(Canvas canvas, Size size) {
    final lats = <double>[
      ...plannedPath.map((c) => c.latitude),
      ...positions.map((p) => p.latitude),
    ];
    final lngs = <double>[
      ...plannedPath.map((c) => c.longitude),
      ...positions.map((p) => p.longitude),
    ];
    if (lats.isEmpty) return;

    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);
    const pad = 24.0;

    Offset toOffset(double lat, double lng) {
      final dx = (maxLng - minLng) == 0
          ? size.width / 2
          : pad + (lng - minLng) / (maxLng - minLng) * (size.width - 2 * pad);
      // Latitude increases upward, so invert y.
      final dy = (maxLat - minLat) == 0
          ? size.height / 2
          : pad + (maxLat - lat) / (maxLat - minLat) * (size.height - 2 * pad);
      return Offset(dx, dy);
    }

    // Planned path line.
    if (plannedPath.length > 1) {
      final linePaint = Paint()
        ..color = AppColors.primary
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(toOffset(plannedPath.first.latitude, plannedPath.first.longitude).dx,
            toOffset(plannedPath.first.latitude, plannedPath.first.longitude).dy);
      for (final c in plannedPath.skip(1)) {
        final o = toOffset(c.latitude, c.longitude);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, linePaint);

      final plannedDot = Paint()..color = AppColors.primary.withValues(alpha: 0.5);
      for (final c in plannedPath) {
        canvas.drawCircle(toOffset(c.latitude, c.longitude), 4, plannedDot);
      }
    }

    // Recorded positions.
    for (final p in positions) {
      final dot = Paint()
        ..color = p.captureMode.name == 'manual'
            ? AppColors.warning
            : AppColors.success;
      canvas.drawCircle(toOffset(p.latitude, p.longitude), 5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) =>
      old.plannedPath != plannedPath || old.positions != positions;
}
