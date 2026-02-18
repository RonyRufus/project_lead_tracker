import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  String _error = '';

  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  String get error => _error;

  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5, // update every 5 metres
  );

  /// Request necessary permissions. Returns true if granted.
  Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _error = 'Location services are disabled.';
      notifyListeners();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _error = 'Location permission denied.';
        notifyListeners();
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _error = 'Location permission permanently denied.';
      notifyListeners();
      return false;
    }

    return true;
  }

  /// Start continuous GPS tracking.
  Future<void> startTracking() async {
    if (_isTracking) return;
    final granted = await requestPermissions();
    if (!granted) return;

    _isTracking = true;
    notifyListeners();

    _positionStream =
        Geolocator.getPositionStream(locationSettings: _locationSettings)
            .listen(
      (position) {
        _currentPosition = position;
        _error = '';
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );

    // Get initial fix immediately
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      notifyListeners();
    } catch (e) {
      // Will be populated by stream
    }
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
    notifyListeners();
  }

  /// Returns the current position or fetches a one-time fix.
  Future<Position?> getCurrentPosition() async {
    if (_currentPosition != null) return _currentPosition;
    final granted = await requestPermissions();
    if (!granted) return null;
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
