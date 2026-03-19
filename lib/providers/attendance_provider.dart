// providers/attendance_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
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
  
  // Settings - Shift 1 (العياده - شفت 1)  [always enabled]
  int _shiftStartHour = 11;
  int _shiftStartMinute = 0;
  // Settings - Shift 2 (العياده - شفت 2)
  bool _shift2Enabled = true;
  int _shift2StartHour = 19;
  int _shift2StartMinute = 0;
  // Settings - Shift 3 (المركز - صباحي)
  bool _shift3Enabled = true;
  int _shift3StartHour = 10;
  int _shift3StartMinute = 0;
  // Settings - Shift 4 (المركز - مسائي)
  bool _shift4Enabled = true;
  int _shift4StartHour = 19;
  int _shift4StartMinute = 0;
  int _lateThresholdMinutes = 10;
  int _absentAfterMinutes = 30;
  
  // Geofencing Settings
  bool _locationRestrictionEnabled = false;
  List<Map<String, dynamic>> _allowedLocations = []; // [{'name': '..', 'lat': .., 'lng': ..}]

  StreamSubscription? _recordsSubscription;
  StreamSubscription? _notifSubscription;
  StreamSubscription? _settingsSubscription;

  List<AttendanceRecord> get records => _records;
  List<Map<String, dynamic>> get adminNotifications => _adminNotifications;
  int get shiftStartHour => _shiftStartHour;
  int get shiftStartMinute => _shiftStartMinute;
  bool get shift2Enabled => _shift2Enabled;
  int get shift2StartHour => _shift2StartHour;
  int get shift2StartMinute => _shift2StartMinute;
  bool get shift3Enabled => _shift3Enabled;
  int get shift3StartHour => _shift3StartHour;
  int get shift3StartMinute => _shift3StartMinute;
  bool get shift4Enabled => _shift4Enabled;
  int get shift4StartHour => _shift4StartHour;
  int get shift4StartMinute => _shift4StartMinute;
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
    _initSupabase();
    _startAutoAbsentTimer();
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

  /// Returns the correct shift start for the given day and location name.
  /// يختار الشيفت اللي ينتمي له الموظف بناءً على أقل تأخير حقيقي:
  ///   - لو سجل قبل بداية كل الشيفتات → الشيفت الأول
  ///   - لو سجل بعد بداية شيفت → أحدث شيفت بدأ قبله (أي الشيفت الصح)
  DateTime shiftStartForDay(DateTime day, String? locationName) {
    // جمع كل الشيفتات حسب الموقع
    List<DateTime> candidateShifts = [];

    if (locationName != null && _isMorkazLocation(locationName)) {
      // شيفتات المركز
      if (_shift3Enabled) candidateShifts.add(DateTime(day.year, day.month, day.day, _shift3StartHour, _shift3StartMinute));
      if (_shift4Enabled) candidateShifts.add(DateTime(day.year, day.month, day.day, _shift4StartHour, _shift4StartMinute));
      if (candidateShifts.isEmpty) {
        // لو الاتنين معطلين نرجع الشيفت الافتراضي
        return DateTime(day.year, day.month, day.day, _shiftStartHour, _shiftStartMinute);
      }
    } else if (locationName == null) {
      // لو مفيش موقع، نجرب كل الشيفتات
      candidateShifts.add(DateTime(day.year, day.month, day.day, _shiftStartHour, _shiftStartMinute));
      if (_shift2Enabled) candidateShifts.add(DateTime(day.year, day.month, day.day, _shift2StartHour, _shift2StartMinute));
      if (_shift3Enabled) candidateShifts.add(DateTime(day.year, day.month, day.day, _shift3StartHour, _shift3StartMinute));
      if (_shift4Enabled) candidateShifts.add(DateTime(day.year, day.month, day.day, _shift4StartHour, _shift4StartMinute));
    } else {
      // شيفتات العيادة
      candidateShifts.add(DateTime(day.year, day.month, day.day, _shiftStartHour, _shiftStartMinute));
      if (_shift2Enabled) candidateShifts.add(DateTime(day.year, day.month, day.day, _shift2StartHour, _shift2StartMinute));
    }

    candidateShifts.sort((a, b) => a.compareTo(b));

    // اختر الشيفت الذي يقلل الفارق الزمني (absolute difference) بين وقت الدخول وبداية الشيفت.
    // هذا يحل مشكلة تسجيل الدخول المبكر (early check-in) حيث لم تكن الشروط السابقة تلتقطه 
    // بشكل صحيح مما كان يؤدي لحساب تأخير ضخم على الشيفت السابق.
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

  bool _isMorkazLocation(String? locationName) {
    if (locationName == null) return false;
    return locationName.contains('مركز') || locationName.contains('بسيون') || locationName.contains('السنطة');
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
    // 1. Always verify location when locations are configured
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
    int? shiftStartHour,
    int? shiftStartMinute,
    bool? shift2Enabled,
    int? shift2StartHour,
    int? shift2StartMinute,
    bool? shift3Enabled,
    int? shift3StartHour,
    int? shift3StartMinute,
    bool? shift4Enabled,
    int? shift4StartHour,
    int? shift4StartMinute,
    int? lateThresholdMinutes,
    int? absentAfterMinutes,
    bool? locationRestrictionEnabled,
    List<Map<String, dynamic>>? allowedLocations,
  }) async {
    if (shiftStartHour != null) {
      _shiftStartHour = shiftStartHour;
      await _supabaseService.saveSetting('shiftStartHour', shiftStartHour.toString());
    }
    if (shiftStartMinute != null) {
      _shiftStartMinute = shiftStartMinute;
      await _supabaseService.saveSetting('shiftStartMinute', shiftStartMinute.toString());
    }
    if (shift2Enabled != null) {
      _shift2Enabled = shift2Enabled;
      await _supabaseService.saveSetting('shift2Enabled', shift2Enabled.toString());
    }
    if (shift2StartHour != null) {
      _shift2StartHour = shift2StartHour;
      await _supabaseService.saveSetting('shift2StartHour', shift2StartHour.toString());
    }
    if (shift2StartMinute != null) {
      _shift2StartMinute = shift2StartMinute;
      await _supabaseService.saveSetting('shift2StartMinute', shift2StartMinute.toString());
    }
    if (shift3Enabled != null) {
      _shift3Enabled = shift3Enabled;
      await _supabaseService.saveSetting('shift3Enabled', shift3Enabled.toString());
    }
    if (shift3StartHour != null) {
      _shift3StartHour = shift3StartHour;
      await _supabaseService.saveSetting('shift3StartHour', shift3StartHour.toString());
    }
    if (shift3StartMinute != null) {
      _shift3StartMinute = shift3StartMinute;
      await _supabaseService.saveSetting('shift3StartMinute', shift3StartMinute.toString());
    }
    if (shift4Enabled != null) {
      _shift4Enabled = shift4Enabled;
      await _supabaseService.saveSetting('shift4Enabled', shift4Enabled.toString());
    }
    if (shift4StartHour != null) {
      _shift4StartHour = shift4StartHour;
      await _supabaseService.saveSetting('shift4StartHour', shift4StartHour.toString());
    }
    if (shift4StartMinute != null) {
      _shift4StartMinute = shift4StartMinute;
      await _supabaseService.saveSetting('shift4StartMinute', shift4StartMinute.toString());
    }
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
    notifyListeners();
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
    if (settings.containsKey('shiftStartHour')) _shiftStartHour = int.parse(settings['shiftStartHour']!);
    if (settings.containsKey('shiftStartMinute')) _shiftStartMinute = int.parse(settings['shiftStartMinute']!);
    if (settings.containsKey('shift2Enabled')) _shift2Enabled = settings['shift2Enabled'] == 'true';
    if (settings.containsKey('shift2StartHour')) _shift2StartHour = int.parse(settings['shift2StartHour']!);
    if (settings.containsKey('shift2StartMinute')) _shift2StartMinute = int.parse(settings['shift2StartMinute']!);
    if (settings.containsKey('shift3Enabled')) _shift3Enabled = settings['shift3Enabled'] == 'true';
    if (settings.containsKey('shift3StartHour')) _shift3StartHour = int.parse(settings['shift3StartHour']!);
    if (settings.containsKey('shift3StartMinute')) _shift3StartMinute = int.parse(settings['shift3StartMinute']!);
    if (settings.containsKey('shift4Enabled')) _shift4Enabled = settings['shift4Enabled'] == 'true';
    if (settings.containsKey('shift4StartHour')) _shift4StartHour = int.parse(settings['shift4StartHour']!);
    if (settings.containsKey('shift4StartMinute')) _shift4StartMinute = int.parse(settings['shift4StartMinute']!);
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

    // Ensure required fixed locations are present
    final requiredLocations = [
      {'name': 'أسنان سكان بسيون', 'lat': 30.939249, 'lng': 30.814687},
      {'name': 'بري وبانوراما', 'lat': 30.724964, 'lng': 31.121525},
      {'name': 'أسنان سكان السنطة', 'lat': 30.728838, 'lng': 31.123164},
      {'name': 'العياده', 'lat': 30.726037, 'lng': 31.121446},
    ];
    bool locationListChanged = false;
    for (final req in requiredLocations) {
      final alreadyExists = _allowedLocations.any((l) => l['name'] == req['name']);
      if (!alreadyExists) {
        _allowedLocations.add(Map<String, dynamic>.from(req));
        locationListChanged = true;
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

  /// إحصائيات شهرية لكل موظف
  Map<String, EmployeeStat> reportForMonth(int year, int month) {
    final Map<String, EmployeeStat> stats = {};

    for (final r in _records) {
      if (r.checkInTime.year != year || r.checkInTime.month != month) continue;

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

