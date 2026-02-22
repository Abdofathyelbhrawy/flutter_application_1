// services/notification_service.dart
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    // Request Android 13+ notification permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> showCheckInNotification({
    required String name,
    required bool isLate,
    required int minutesLate,
  }) async {
    await init();
    final String title = isLate ? '⚠️ تأخير في الحضور' : '✅ حضور جديد';
    final String body = isLate
        ? '$name وصل متأخراً $minutesLate دقيقة'
        : '$name سجّل حضوره في الوقت';
    await _show(
      id: name.hashCode & 0x7FFFFFFF,
      title: title,
      body: body,
      color: isLate ? const Color(0xFFFF9800) : const Color(0xFF4CAF50),
    );
  }

  Future<void> showCheckOutNotification({required String name}) async {
    await init();
    await _show(
      id: (name.hashCode + 1000) & 0x7FFFFFFF,
      title: '🚪 انصراف',
      body: '$name سجّل انصرافه',
      color: const Color(0xFF2196F3),
    );
  }

  Future<void> showAbsentNotification({required String name}) async {
    await init();
    await _show(
      id: (name.hashCode + 2000) & 0x7FFFFFFF,
      title: '🚫 غياب تلقائي',
      body: 'تم تسجيل $name كغائب لعدم كتابة عذر',
      color: const Color(0xFFF44336),
    );
  }

  Future<void> showExcuseNotification({
    required String name,
    required String excuse,
  }) async {
    await init();
    await _show(
      id: (name.hashCode + 3000) & 0x7FFFFFFF,
      title: '📝 عذر جديد',
      body: '$name: $excuse',
      color: const Color(0xFF2196F3),
    );
  }

  bool showNotifications = false;

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required Color color,
  }) async {
    if (!showNotifications) return;

    final androidDetails = AndroidNotificationDetails(
      'attendance_channel',
      'إشعارات الحضور',
      channelDescription: 'إشعارات حضور وانصراف موظفي مركز الأشعة',
      importance: Importance.high,
      priority: Priority.high,
      color: color,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(id, title, body, details);
  }
}
