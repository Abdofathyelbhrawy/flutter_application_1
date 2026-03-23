// providers/attendance_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance_record.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../services/location_tracker.dart';

final _notifService = NotificationService();
final _supabaseService = SupabaseService();
final _locationTracker = LocationTracker();

class AttendanceProvider extends ChangeNotifier {
  List<AttendanceRecord> _records = [];
  List<Map<String, dynamic>> _adminNotifications = [];
  
  // Device Binding
  String? _myDeviceId;
  Map<String, String> _deviceBindings = {}; // {"الاسم": "device_uuid"}

  int _lateThresholdMinutes = 20;
  int _absentAfterMinutes = 30;
  
  // Geofencing Settings
  bool _locationRestrictionEnabled = false;
  List<Map<String, dynamic>> _allowedLocations = []; // [{'name': '..', 'lat': .., 'lng': ..}]

  StreamSubscription? _recordsSubscription;
  StreamSubscription? _notifSubscription;
  StreamSubscription? _settingsSubscription;

  List<AttendanceRecord> get records => _records;
  List<Map<String, dynamic>> get adminNotifications => _adminNotifications;
  Map<String, String> get deviceBindings => _deviceBindings;
  int get lateThresholdMinutes => _lateThresholdMinutes;
  int get absentAfterMinutes => _absentAfterMinutes;
  
  bool get locationRestrictionEnabled => _locationRestrictionEnabled;
  List<Map<String, dynamic>> get allowedLocations => _allowedLocations;

  // Location tracking state
  bool get isTrackingLocation => _locationTracker.isTracking;
  String? get trackedEmployeeName => _locationTracker.trackedName;
  bool get isEmployeeOutOfRange => _locationTracker.isOutOfRange;

  List<AttendanceRecord> get todayRecords {
    final now = DateTime.now();
    return _records.where((r) {
      return r.checkInTime.year == now.year &&
          r.checkInTime.month == now.month &&
          r.checkInTime.day == now.day;
    }).toList()
      ..sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
  }

  List<AttendanceRecord> get allRecords =>
      List.from(_records)..sort((a, b) => b.checkInTime.compareTo(a.checkInTime));

  Map<String, List<AttendanceRecord>> get recordsByDate {
    final Map<String, List<AttendanceRecord>> grouped = {};
    for (final r in allRecords) {
      final key = '${r.checkInTime.year}-'
          '${r.checkInTime.month.toString().padLeft(2, '0')}-'
          '${r.checkInTime.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(r);
    }
    return grouped;
  }

  List<Map<String, dynamic>> get unreadNotifications =>
      _adminNotifications.where((n) => !(n['read'] as bool)).toList();

  AttendanceProvider() {
    _initDeviceId();
    _initSupabase();
    _startAutoAbsentTimer();
  }

  Future<void> _initDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _myDeviceId = prefs.getString('device_token');
      if (_myDeviceId == null) {
        _myDeviceId = const Uuid().v4();
        await prefs.setString('device_token', _myDeviceId!);
      }
    } catch (_) {
      // Ignore if SharedPreferences fails (e.g., testing without mocks)
    }
  }

  Future<void> _initSupabase() async {
    // Load settings once first (to populate values before stream fires)
    await _loadSettings();

    // Then subscribe to real-time settings changes
    _settingsSubscription = _supabaseService.streamSettings().listen((settings) {
      _applySettings(settings);
    });

    _recordsSubscription = _supabaseService.streamRecords().listen((data) {
      _records = data;
      notifyListeners();
    });

    _notifSubscription = _supabaseService.streamNotifications().listen((data) {
      _adminNotifications = data;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _recordsSubscription?.cancel();
    _notifSubscription?.cancel();
    _settingsSubscription?.cancel();
    super.dispose();
  }

  DateTime shiftStartForDay(DateTime day, String? locationName) {
    List<DateTime> candidateShifts = [];

    // Find location in _allowedLocations
    Map<String, dynamic>? loc;
    if (locationName != null) {
      loc = _allowedLocations.firstWhere(
        (l) => l['name'] == locationName,
        orElse: () => <String, dynamic>{}, // Return empty map if not found
      );
    }
    
    // Add shifts from the matched location
    if (loc != null && loc.isNotEmpty && loc.containsKey('shifts')) {
      final shifts = loc['shifts'] as List<dynamic>;
      for (final s in shifts) {
        candidateShifts.add(DateTime(day.year, day.month, day.day, s['hour'] as int, s['minute'] as int));
      }
    }

    if (candidateShifts.isEmpty) {
      // Fallback to clinic shifts if location not found or has no shifts
      final clinicLoc = _allowedLocations.firstWhere(
        (l) => l['name'] == 'العياده',
        orElse: () => <String, dynamic>{},
      );
      if (clinicLoc.isNotEmpty && clinicLoc.containsKey('shifts')) {
        final shifts = clinicLoc['shifts'] as List<dynamic>;
        for (final s in shifts) {
          candidateShifts.add(DateTime(day.year, day.month, day.day, s['hour'] as int, s['minute'] as int));
        }
      }
    }

    // Default fallback if NOTHING is configured
    if (candidateShifts.isEmpty) {
      candidateShifts.add(DateTime(day.year, day.month, day.day, 11, 0));
      candidateShifts.add(DateTime(day.year, day.month, day.day, 19, 0));
    }

    candidateShifts.sort((a, b) => a.compareTo(b));

    // اختر الشيفت الذي يقلل الفارق الزمني (absolute difference) بين وقت الدخول وبداية الشيفت.
    DateTime bestShift = candidateShifts.first;
    int minDiff = (day.difference(bestShift).inMinutes).abs();

    for (int i = 1; i < candidateShifts.length; i++) {
      final s = candidateShifts[i];
      final diff = (day.difference(s).inMinutes).abs();
      if (diff < minDiff) {
        minDiff = diff;
        bestShift = s;
      }
    }

    return bestShift;
  }

  // --- Location Logic ---
  
  /// Verifies that the user is within range of one of the allowed locations.
  /// Also returns the matched location name via [locationNameOut].
  /// Always runs when [_allowedLocations] is not empty.
  Future<String?> verifyLocation({StringBuffer? locationNameOut}) async {
    if (_allowedLocations.isEmpty) return null;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return 'location_disabled';

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return 'permission_denied';
    }
    if (permission == LocationPermission.deniedForever) return 'permission_denied_forever';

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    for (final loc in _allowedLocations) {
      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        loc['lat'],
        loc['lng'],
      );
      if (distance <= 100) {
        locationNameOut?.write(loc['name'] as String);
        return null; // within range ✓
      }
    }
    return 'out_of_range';
  }

  // Check in a staff member
  Future<String> checkIn(String name) async {
    // 1. Device Binding Check
    if (_myDeviceId == null) await _initDeviceId();
    if (_myDeviceId != null) {
      final boundDeviceId = _deviceBindings[name];
      if (boundDeviceId != null) {
        if (boundDeviceId != _myDeviceId) {
          return 'device_bound_to_other_device'; // "مسجل على جهاز آخر"
        }
      } else {
        if (_deviceBindings.containsValue(_myDeviceId)) {
          final existingName = _deviceBindings.entries.firstWhere((e) => e.value == _myDeviceId).key;
          if (existingName.toLowerCase() != name.toLowerCase()) {
            return 'device_used_by_other_user'; // "مربوط بالموظف X"
          }
        } else {
          // Both free: Bind them!
          final newBindings = Map<String, String>.from(_deviceBindings);
          newBindings[name] = _myDeviceId!;
          await updateSettings(deviceBindings: newBindings);
        }
      }
    }

    // 2. Always verify location when locations are configured
    String? locationName;
    if (_allowedLocations.isNotEmpty) {
      final locationNameBuf = StringBuffer();
      final locError = await verifyLocation(locationNameOut: locationNameBuf);
      if (locError != null) return locError; // blocks check-in if out of range
      if (locationNameBuf.isNotEmpty) locationName = locationNameBuf.toString();
    }

    // 2. Check if already checked in for the same shift today
    final now = DateTime.now();
    final shiftStart = shiftStartForDay(now, locationName);

    final alreadyIn = _records.any((r) {
      if (r.name.toLowerCase() != name.toLowerCase()) return false;
      if (r.checkInTime.year != now.year ||
          r.checkInTime.month != now.month ||
          r.checkInTime.day != now.day) {
        return false;
      }
      // Compare against the same shift window
      final recordShiftStart = shiftStartForDay(r.checkInTime, r.locationName);
      return recordShiftStart == shiftStart;
    });

    if (alreadyIn) return 'already_in';
    final graceEnd = shiftStart.add(Duration(minutes: _lateThresholdMinutes));
    final late = now.isAfter(graceEnd);
    final minutesLate = late ? now.difference(shiftStart).inMinutes : 0;

    final status = late ? AttendanceStatus.late : AttendanceStatus.present;

    final record = AttendanceRecord(
      name: name,
      checkInTime: now,
      status: status,
      locationName: locationName,
      minutesLate: minutesLate,
    );

    // Save to Supabase
    await _supabaseService.insertRecord(record);

    // Show Notification
    _notifService.showCheckInNotification(
      name: name,
      isLate: late,
      minutesLate: minutesLate,
    );

    // Add to Admin Notifications (Supabase)
    await _supabaseService.insertNotification({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': late ? 'late_arrival' : 'arrival',
      'name': name,
      'time': now.toUtc().toIso8601String(),
      'minutesLate': minutesLate,
      'recordId': record.id,
      'read': false,
    });

    // Start location tracking after successful check-in
    if (_allowedLocations.isNotEmpty) {
      _locationTracker.startTracking(
        employeeName: name,
        recordId: record.id,
        allowedLocations: _allowedLocations,
      );
      notifyListeners();
    }

    return late ? 'late' : 'success';
  }

  // Check out
  Future<void> checkOut(String recordId) async {
    final idx = _records.indexWhere((r) => r.id == recordId);
    if (idx == -1) return;
    
    final record = _records[idx];
    record.checkOutTime = DateTime.now();
        if (record.status != AttendanceStatus.late && 
          record.status != AttendanceStatus.lateWithExcuse &&
          record.status != AttendanceStatus.lateExcusePending) {
        record.status = AttendanceStatus.checkedOut;
      }

    await _supabaseService.updateRecord(record);
    _notifService.showCheckOutNotification(name: record.name);

    // Stop location tracking on check-out
    if (_locationTracker.isTracking && _locationTracker.trackedName?.toLowerCase() == record.name.toLowerCase()) {
      _locationTracker.stopTracking();
      notifyListeners();
    }
  }

  // Submit excuse
  Future<void> submitExcuse(String recordId, String excuse) async {
    final idx = _records.indexWhere((r) => r.id == recordId);
    if (idx == -1) return;
    
    final record = _records[idx];
    record.excuse = excuse;
    record.status = AttendanceStatus.lateExcusePending;

    await _supabaseService.updateRecord(record);

    _notifService.showExcuseNotification(name: record.name, excuse: excuse);
    
    // Notify Admin about new excuse
     await _supabaseService.insertNotification({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': 'excuse_submitted',
      'name': record.name,
      'time': DateTime.now().toUtc().toIso8601String(),
      'minutesLate': record.minutesLate,
      'recordId': recordId,
      'read': false,
    });
  }

  // Admin: Justify Excuse (Approve/Reject)
  Future<void> justifyExcuse(String recordId, bool isAccepted) async {
    final idx = _records.indexWhere((r) => r.id == recordId);
    if (idx == -1) return;

    final record = _records[idx];
    record.status = isAccepted ? AttendanceStatus.lateWithExcuse : AttendanceStatus.absent;
    
    await _supabaseService.updateRecord(record);
    notifyListeners();
  }

  // Mark absent (Auto)
  Future<void> _markAbsent(String recordId) async {
    final idx = _records.indexWhere((r) => r.id == recordId);
    if (idx == -1) return;
    
    final record = _records[idx];
    // Only update if still 'late' (not engaged yet)
    if (record.status == AttendanceStatus.late) {
      record.status = AttendanceStatus.absent;
      
      await _supabaseService.updateRecord(record);

      _notifService.showAbsentNotification(name: record.name);
      
      await _supabaseService.insertNotification({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': 'auto_absent',
        'name': record.name,
        'time': DateTime.now().toUtc().toIso8601String(),
        'minutesLate': record.minutesLate,
        'recordId': recordId,
        'read': false,
      });
    }
  }

  // Admin: Mark Read
  Future<void> markNotificationRead(String notifId) async {
    await _supabaseService.markNotificationRead(notifId);
  }

  Future<void> markAllNotificationsRead() async {
    final ids = unreadNotifications.map((n) => n['id'] as String).toList();
    await _supabaseService.markAllNotificationsRead(ids);
  }

  Future<void> clearAllNotifications() async {
    await _supabaseService.clearAllNotifications();
  }

  // Timer for auto-absent
  void _startAutoAbsentTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 60));
      _checkAutoAbsent();
      return true;
    });
  }

  void _checkAutoAbsent() {
    final now = DateTime.now();
    // Use local copy of records, updates will sync back
    for (final record in _records) {
      if (record.status == AttendanceStatus.late) {
        final shiftStart = shiftStartForDay(record.checkInTime, record.locationName);
        final absentThreshold = shiftStart.add(Duration(minutes: _absentAfterMinutes));
        if (now.isAfter(absentThreshold)) {
          _markAbsent(record.id);
        }
      }
    }
  }
  Future<void> addManualLocation(String name, double lat, double lng) async {
    final newLoc = {
      'name': name,
      'lat': lat,
      'lng': lng,
    };
    
    final updatedList = List<Map<String, dynamic>>.from(_allowedLocations)..add(newLoc);
    await updateSettings(allowedLocations: updatedList);
  }

  // Settings
  Future<void> updateSettings({
    int? lateThresholdMinutes,
    int? absentAfterMinutes,
    bool? locationRestrictionEnabled,
    List<Map<String, dynamic>>? allowedLocations,
    Map<String, String>? deviceBindings,
  }) async {
    if (lateThresholdMinutes != null) {
      _lateThresholdMinutes = lateThresholdMinutes;
      await _supabaseService.saveSetting('lateThresholdMinutes', lateThresholdMinutes.toString());
    }
    if (absentAfterMinutes != null) {
      _absentAfterMinutes = absentAfterMinutes;
      await _supabaseService.saveSetting('absentAfterMinutes', absentAfterMinutes.toString());
    }
    if (locationRestrictionEnabled != null) {
      _locationRestrictionEnabled = locationRestrictionEnabled;
      await _supabaseService.saveSetting('locationRestrictionEnabled', locationRestrictionEnabled.toString());
    }
    if (allowedLocations != null) {
      _allowedLocations = allowedLocations;
      await _supabaseService.saveSetting('allowedLocations', jsonEncode(allowedLocations));
    }
    if (deviceBindings != null) {
      _deviceBindings = deviceBindings;
      await _supabaseService.saveSetting('deviceBindings', jsonEncode(deviceBindings));
    }
    notifyListeners();
  }

  Future<void> unbindDevice(String employeeName) async {
    if (_deviceBindings.containsKey(employeeName)) {
      final newBindings = Map<String, String>.from(_deviceBindings);
      newBindings.remove(employeeName);
      await updateSettings(deviceBindings: newBindings);
    }
  }
  
  // Helper to add current location
  Future<void> addCurrentLocation(String name) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services are disabled.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception('Location permissions are denied');
    }
    
    if (permission == LocationPermission.deniedForever) throw Exception('Location permissions are permanently denied');

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
    
    final newLoc = {
      'name': name,
      'lat': position.latitude,
      'lng': position.longitude,
    };
    
    final updatedList = List<Map<String, dynamic>>.from(_allowedLocations)..add(newLoc);
    await updateSettings(allowedLocations: updatedList);
  }
  
  Future<void> removeLocation(int index) async {
    if (index >= 0 && index < _allowedLocations.length) {
      final updatedList = List<Map<String, dynamic>>.from(_allowedLocations)..removeAt(index);
      await updateSettings(allowedLocations: updatedList);
    }
  }

  Future<void> _loadSettings() async {
    final settings = await _supabaseService.loadSettings();
    _applySettings(settings);
  }

  /// يُطبَّق عند أول تحميل وعند كل تغيير real-time في الإعدادات
  void _applySettings(Map<String, String> settings) {
    if (settings.containsKey('lateThresholdMinutes')) _lateThresholdMinutes = int.parse(settings['lateThresholdMinutes']!);
    if (settings.containsKey('absentAfterMinutes')) _absentAfterMinutes = int.parse(settings['absentAfterMinutes']!);

    if (settings.containsKey('locationRestrictionEnabled')) {
      _locationRestrictionEnabled = settings['locationRestrictionEnabled'] == 'true';
    }
    if (settings.containsKey('allowedLocations')) {
      try {
        final List<dynamic> decoded = jsonDecode(settings['allowedLocations']!);
        _allowedLocations = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (e) {
        if (kDebugMode) print('Error parsing locations: $e');
      }
    }
    if (settings.containsKey('deviceBindings')) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(settings['deviceBindings']!);
        _deviceBindings = decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (e) {
        if (kDebugMode) print('Error parsing deviceBindings: $e');
      }
    }

    // Ensure required fixed locations are present
    final requiredLocations = [
      {
        'name': 'أسنان سكان بسيون',
        'lat': 30.939249,
        'lng': 30.814687,
        'shifts': [
          {'hour': 9, 'minute': 0},
          {'hour': 14, 'minute': 0},
        ]
      },
      {
        'name': 'بري وبانوراما',
        'lat': 30.724964,
        'lng': 31.121525,
        'shifts': [
          {'hour': 9, 'minute': 0},
          {'hour': 17, 'minute': 0},
        ]
      },
      {
        'name': 'أسنان سكان السنطة',
        'lat': 30.728838,
        'lng': 31.123164,
        'shifts': [
          {'hour': 9, 'minute': 0},
          {'hour': 11, 'minute': 0},
          {'hour': 13, 'minute': 0},
          {'hour': 15, 'minute': 0},
        ]
      },
      {
        'name': 'العياده',
        'lat': 30.726037,
        'lng': 31.121446,
        'shifts': [
          {'hour': 11, 'minute': 0},
          {'hour': 19, 'minute': 0},
        ]
      },
    ];
    
    bool locationListChanged = false;
    for (final req in requiredLocations) {
      final existingIdx = _allowedLocations.indexWhere((l) => l['name'] == req['name']);
      if (existingIdx == -1) {
        _allowedLocations.add(Map<String, dynamic>.from(req));
        locationListChanged = true;
      } else {
        // If it exists but has no shifts configured (or needs an update), inject default shifts
        // Force update to accept new image schedules
        if (req['name'] == 'أسنان سكان السنطة' ||
            req['name'] == 'بري وبانوراما' ||
            req['name'] == 'أسنان سكان بسيون' ||
            !_allowedLocations[existingIdx].containsKey('shifts') ||
            (_allowedLocations[existingIdx]['shifts'] as List).isEmpty) {
          _allowedLocations[existingIdx]['shifts'] = req['shifts'];
          locationListChanged = true;
        }
      }
    }
    
    if (locationListChanged) {
      _supabaseService.saveSetting('allowedLocations', jsonEncode(_allowedLocations));
    }

    notifyListeners();
  }

  AttendanceRecord? getTodayRecord(String name) {
    final today = DateTime.now();
    try {
      return _records.lastWhere((r) =>
          r.name.toLowerCase() == name.toLowerCase() &&
          r.checkInTime.year == today.year &&
          r.checkInTime.month == today.month &&
          r.checkInTime.day == today.day);
    } catch (_) {
      return null;
    }
  }

  Map<String, int> get todayStats {
    final tr = todayRecords;
    return {
      'present': tr.where((r) => r.status == AttendanceStatus.present || r.status == AttendanceStatus.checkedOut).length,
      'late': tr.where((r) => r.status == AttendanceStatus.late || r.status == AttendanceStatus.lateExcusePending).length,
      'lateWithExcuse': tr.where((r) => r.status == AttendanceStatus.lateWithExcuse).length,
      'absent': tr.where((r) => r.status == AttendanceStatus.absent).length,
    };
  }

  Future<void> clearAll() async {
    await _supabaseService.clearAllRecords();
  }

  Future<void> clearToday() async {
     // Get IDs of today's records
    final todayRecs = todayRecords;
    final ids = todayRecs.map((r) => r.id).toList();
    await _supabaseService.deleteRecords(ids);
  }

  /// إحصائيات شهرية لكل موظف (مع إمكانية الفلترة بالفرع)
  Map<String, EmployeeStat> reportForMonth(int year, int month, {String? locationName}) {
    final Map<String, EmployeeStat> stats = {};

    for (final r in _records) {
      if (r.checkInTime.year != year || r.checkInTime.month != month) continue;
      
      // التصفية حسب الفرع لو تم اختياره
      if (locationName != null && locationName != 'الكل') {
        if (r.locationName != locationName) continue;
      }

      final stat = stats.putIfAbsent(r.name, () => EmployeeStat(name: r.name));

      switch (r.status) {
        case AttendanceStatus.present:
        case AttendanceStatus.checkedOut:
          stat.present++;
          break;
        case AttendanceStatus.late:
        case AttendanceStatus.lateWithExcuse:
        case AttendanceStatus.lateExcusePending:
          stat.late++;
          if (r.minutesLate > 0) stat.totalLateMinutes += r.minutesLate;
          break;
        case AttendanceStatus.absent:
          stat.absent++;
          break;
      }
    }

    return stats;
  }
}

/// بيانات إحصائية لموظف واحد في شهر معين
class EmployeeStat {
  final String name;
  int present = 0;
  int late = 0;
  int absent = 0;
  int totalLateMinutes = 0;

  EmployeeStat({required this.name});

  int get total => present + late + absent;
}

