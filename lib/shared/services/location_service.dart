/// Shared location service interface.
/// Each feature that needs GPS (patrol, incidents, conflict_response)
/// depends on this — not on geolocator directly.
abstract class LocationService {
  Future<({double latitude, double longitude})> getCurrentPosition();
  Stream<({double latitude, double longitude})> positionStream();
  Future<bool> requestPermission();
}
