import 'package:geolocator/geolocator.dart';

import '../../core/errors/exceptions.dart';
import 'location_service.dart';

/// Concrete [LocationService] backed by the `geolocator` package.
///
/// Permission and service-availability failures surface as [PermissionException]
/// so callers can fall back to manual waypoint entry instead of crashing.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<bool> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const PermissionException('Location services are disabled.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const PermissionException(
          'Location permission permanently denied. Enable it in settings.');
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Future<({double latitude, double longitude})> getCurrentPosition() async {
    if (!await requestPermission()) {
      throw const PermissionException('Location permission not granted.');
    }
    final position = await Geolocator.getCurrentPosition();
    return (latitude: position.latitude, longitude: position.longitude);
  }

  @override
  Stream<({double latitude, double longitude})> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).map((p) => (latitude: p.latitude, longitude: p.longitude));
  }
}
