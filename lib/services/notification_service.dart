// services/notification_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;

// Only import flutter_local_notifications on non-web platforms
// ignore: depend_on_referenced_packages
import 'notification_service_mobile.dart' if (dart.library.html) 'notification_service_web.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool showNotifications = false;

  Future<void> init() async {
    if (kIsWeb) return; // No-op on web
    await initMobile();
  }

  Future<void> showCheckInNotification({
    required String name,
    required bool isLate,
    required int minutesLate,
  }) async {
    if (kIsWeb || !showNotifications) return;
    await showMobileCheckIn(name: name, isLate: isLate, minutesLate: minutesLate);
  }

  Future<void> showCheckOutNotification({required String name}) async {
    if (kIsWeb || !showNotifications) return;
    await showMobileCheckOut(name: name);
  }

  Future<void> showAbsentNotification({required String name}) async {
    if (kIsWeb || !showNotifications) return;
    await showMobileAbsent(name: name);
  }

  Future<void> showExcuseNotification({
    required String name,
    required String excuse,
  }) async {
    if (kIsWeb || !showNotifications) return;
    await showMobileExcuse(name: name, excuse: excuse);
  }
}
