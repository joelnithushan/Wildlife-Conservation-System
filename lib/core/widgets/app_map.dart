import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../shared/models/geo_coordinate.dart';
import '../../shared/models/patrol_position.dart';
import '../enums/app_enums.dart';
import '../theme/app_theme.dart';

/// Shared Google Maps widgets so every real map in WildGuard looks and behaves
/// the same (§52). These render the Google map only — call sites decide between
/// a map and the lightweight canvas preview via `mapsEnabledProvider` (a
/// GoogleMap platform view can't render in headless tests).
///
/// Minneriya National Park centre — the default camera target.
const LatLng _parkCenter = LatLng(8.03, 80.90);

/// Interactive picker: tap the map or drag the marker to choose a point. The
/// chosen coordinates are reported through [onChanged]; nothing is picked until
/// the user acts (matching the manual-location contract — never fabricated).
class GoogleLocationPicker extends StatelessWidget {
  const GoogleLocationPicker({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onChanged,
    this.height = 240,
  });

  final double? latitude;
  final double? longitude;
  final ValueChanged<({double latitude, double longitude})> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final hasPoint = latitude != null && longitude != null;
    final target = hasPoint ? LatLng(latitude!, longitude!) : _parkCenter;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: GoogleMap(
          initialCameraPosition:
              CameraPosition(target: target, zoom: hasPoint ? 15 : 12),
          onTap: (pos) =>
              onChanged((latitude: pos.latitude, longitude: pos.longitude)),
          markers: {
            if (hasPoint)
              Marker(
                markerId: const MarkerId('picked'),
                position: target,
                draggable: true,
                onDragEnd: (p) =>
                    onChanged((latitude: p.latitude, longitude: p.longitude)),
              ),
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
        ),
      ),
    );
  }
}

/// Read-only map plotting a planned route (polyline) and any recorded positions
/// (markers), fitting the camera to all points.
class GoogleRouteMap extends StatelessWidget {
  const GoogleRouteMap({
    super.key,
    required this.plannedPath,
    this.positions = const [],
    this.height = 200,
  });

  final List<GeoCoordinate> plannedPath;
  final List<PatrolPosition> positions;
  final double height;

  @override
  Widget build(BuildContext context) {
    final points = <LatLng>[
      ...plannedPath.map((c) => LatLng(c.latitude, c.longitude)),
      ...positions.map((p) => LatLng(p.latitude, p.longitude)),
    ];
    final target = points.isNotEmpty ? points.first : _parkCenter;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: target, zoom: 13),
          onMapCreated: (controller) => _fitBounds(controller, points),
          polylines: {
            if (plannedPath.length > 1)
              Polyline(
                polylineId: const PolylineId('planned'),
                points: plannedPath
                    .map((c) => LatLng(c.latitude, c.longitude))
                    .toList(),
                color: AppColors.primary,
                width: 4,
              ),
          },
          markers: {
            for (final p in positions)
              Marker(
                markerId: MarkerId(p.id),
                position: LatLng(p.latitude, p.longitude),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  p.captureMode == CaptureMode.manual
                      ? BitmapDescriptor.hueOrange
                      : BitmapDescriptor.hueGreen,
                ),
              ),
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          liteModeEnabled: true, // static, lightweight preview (Android)
        ),
      ),
    );
  }

  Future<void> _fitBounds(
      GoogleMapController controller, List<LatLng> points) async {
    if (points.length < 2) return;
    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        40,
      ),
    );
  }
}

/// Read-only map centred on a single marker (e.g. an alert location).
class GooglePointMap extends StatelessWidget {
  const GooglePointMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 180,
  });

  final double latitude;
  final double longitude;
  final double height;

  @override
  Widget build(BuildContext context) {
    final target = LatLng(latitude, longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: target, zoom: 14),
          markers: {
            Marker(markerId: const MarkerId('point'), position: target),
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          liteModeEnabled: true,
        ),
      ),
    );
  }
}
