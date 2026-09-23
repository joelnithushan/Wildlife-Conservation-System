import 'package:connectivity_plus/connectivity_plus.dart';

/// Small abstraction over connectivity so screens/services don't call
/// `connectivity_plus` directly.
abstract interface class ConnectivityService {
  Future<bool> isOnline();
  Stream<bool> get connectionChanges;
}

/// Default implementation backed by `connectivity_plus`.
class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Future<bool> isOnline() async =>
      _hasConnection(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get connectionChanges =>
      _connectivity.onConnectivityChanged.map(_hasConnection);
}
