// services/location_tracker.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'supabase_service.dart';

class LocationTracker {
  static final LocationTracker _instance = LocationTracker._internal();
  factory LocationTracker() => _instance;
  LocationTracker._internal();

  final _supabaseService = SupabaseService();

  StreamSubscription<Position>? _positionSubscription;
  String? _trackedName;
  String? _trackedRecordId;
  List<Map<String, dynamic>> _allowedLocations = [];
  bool _isOutOfRange = false;
  DateTime? _lastNotificationTime;

  bool get isTracking => _positionSubscription != null;
  String? get trackedName => _trackedName;
  bool get isOutOfRange => _isOutOfRange;

  /// Cooldown between repeated notifications (3 minutes)
  static const _notifCooldown = Duration(minutes: 3);

  /// Start tracking an employee's location after check-in
  void startTracking({
    required String employeeName,
    required String recordId,
    required List<Map<String, dynamic>> allowedLocations,
  }) {
    // Stop any existing tracking first
    stopTracking();

    if (allowedLocations.isEmpty) return;

    _trackedName = employeeName;
    _trackedRecordId = recordId;
    _allowedLocations = allowedLocations;
    _isOutOfRange = false;
    _lastNotificationTime = null;

    // Use getPositionStream for continuous tracking
    late LocationSettings locationSettings;
    if (kIsWeb) {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // minimum 10 meters before update
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (e) {
        debugPrint('LocationTracker error: $e');
      },
    );

    debugPrint('LocationTracker: Started tracking $employeeName');
  }

  /// Stop tracking
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _trackedName = null;
    _trackedRecordId = null;
    _isOutOfRange = false;
    _lastNotificationTime = null;
  }

  /// Called every time a position update arrives
  void _onPositionUpdate(Position position) {
    if (_allowedLocations.isEmpty || _trackedName == null) return;

    // Check if within range of ANY allowed location
    bool withinRange = false;
    for (final loc in _allowedLocations) {
      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      );
      if (distance <= 100) {
        withinRange = true;
        break;
      }
    }

    if (!withinRange && !_isOutOfRange) {
      // Just left the zone
      _isOutOfRange = true;
      _sendZoneNotification(type: 'left_zone');
    } else if (withinRange && _isOutOfRange) {
      // Just returned to the zone
      _isOutOfRange = false;
      _sendZoneNotification(type: 'returned_zone');
    }
  }

  /// Send a zone notification to admin (with cooldown)
  Future<void> _sendZoneNotification({required String type}) async {
    final now = DateTime.now();
    if (_lastNotificationTime != null &&
        now.difference(_lastNotificationTime!) < _notifCooldown) {
      return; // cooldown — don't spam
    }
    _lastNotificationTime = now;

    try {
      await _supabaseService.insertNotification({
        'id': now.millisecondsSinceEpoch.toString(),
        'type': type,
        'name': _trackedName!,
        'time': now.toUtc().toIso8601String(),
        'minutesLate': 0,
        'recordId': _trackedRecordId ?? '',
        'read': false,
      });
      debugPrint('LocationTracker: Sent $type notification for $_trackedName');
    } catch (e) {
      debugPrint('LocationTracker: Failed to send notification: $e');
    }
  }
}
