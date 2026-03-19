// services/notification_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional import: web stub on web, real implementation on mobile
import 'notification_service_mobile.dart' if (dart.library.js_interop) 'notification_service_web.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool showNotifications = false;

  Future<void> init() async {
    await initMobile();
  }

  Future<void> showCheckInNotification({
    required String name,
    required bool isLate,
    required int minutesLate,
  }) async {
    if (!showNotifications && !kIsWeb) return;
    await showMobileCheckIn(name: name, isLate: isLate, minutesLate: minutesLate);
  }

  Future<void> showCheckOutNotification({required String name}) async {
    if (!showNotifications && !kIsWeb) return;
    await showMobileCheckOut(name: name);
  }

  Future<void> showAbsentNotification({required String name}) async {
    if (!showNotifications && !kIsWeb) return;
    await showMobileAbsent(name: name);
  }

  Future<void> showExcuseNotification({
    required String name,
    required String excuse,
  }) async {
    if (!showNotifications && !kIsWeb) return;
    await showMobileExcuse(name: name, excuse: excuse);
  }
}
