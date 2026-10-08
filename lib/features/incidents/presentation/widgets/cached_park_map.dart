import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Park-centred cached map. No live tiles and no Google Maps key.
///
/// The canvas covers a fixed box around Minneriya. Tapping or dragging places
/// a pin and reports the matching coordinates. The pin is never invented until
/// the user touches the map or supplies coordinates.
class CachedParkMap extends StatelessWidget {
  const CachedParkMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onChanged,
    this.height = 220,
  });

  /// Minneriya National Park centre.
  static const centerLatitude = 8.03;
  static const centerLongitude = 80.90;

  /// Degrees covered by the canvas (about 9 km).
  static const span = 0.08;

  final double? latitude;
  final double? longitude;
  final ValueChanged<({double latitude, double longitude})> onChanged;
  final double height;

  static ({double latitude, double longitude}) coordinateFor(
    Offset local,
    Size size,
  ) {
    final nx = size.width == 0 ? 0.5 : (local.dx / size.width).clamp(0.0, 1.0);
    final ny = size.height == 0 ? 0.5 : (local.dy / size.height).clamp(0.0, 1.0);
    final longitude = centerLongitude - span / 2 + nx * span;
    final latitude = centerLatitude + span / 2 - ny * span;
    return (latitude: latitude, longitude: longitude);
  }

  static Offset? pinOffset(double? latitude, double? longitude, Size size) {
    if (latitude == null || longitude == null || size.width == 0) return null;
    final nx = (longitude - (centerLongitude - span / 2)) / span;
    final ny = ((centerLatitude + span / 2) - latitude) / span;
    if (nx < 0 || nx > 1 || ny < 0 || ny > 1) return null;
    return Offset(nx * size.width, ny * size.height);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final pin = pinOffset(latitude, longitude, size);
          return GestureDetector(
            onTapDown: (details) =>
                onChanged(coordinateFor(details.localPosition, size)),
            onPanUpdate: (details) =>
                onChanged(coordinateFor(details.localPosition, size)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  CustomPaint(
                    size: size,
                    painter: const _ParkMapPainter(),
                  ),
                  if (pin != null)
                    Positioned(
                      left: pin.dx - 16,
                      top: pin.dy - 32,
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.error,
                        size: 36,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ParkMapPainter extends CustomPainter {
  const _ParkMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFD7E6D4),
    );
    final water = Paint()..color = const Color(0xFFB7D4E8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.62, size.height * 0.55),
        width: size.width * 0.42,
        height: size.height * 0.36,
      ),
      water,
    );
    final track = Paint()
      ..color = const Color(0xFF8FA888)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.8)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.2,
        size.width * 0.92,
        size.height * 0.35,
      );
    canvas.drawPath(path, track);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
