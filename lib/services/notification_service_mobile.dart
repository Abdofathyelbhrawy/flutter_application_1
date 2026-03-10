// services/notification_service_mobile.dart
// Mobile implementation using flutter_local_notifications
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/app_theme.dart';

final _plugin = FlutterLocalNotificationsPlugin();
bool _initialized = false;

Future<void> initMobile() async {
  if (_initialized) return;
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
  await _plugin.initialize(initSettings);
  await _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  _initialized = true;
}

Future<void> showMobileCheckIn({
  required String name,
  required bool isLate,
  required int minutesLate,
}) async {
  await initMobile();
  final title = isLate ? '⚠️ تأخير في الحضور' : '✅ حضور جديد';
  final body = isLate
      ? '$name وصل متأخراً ${AppTheme.formatLateTime(minutesLate)}'
      : '$name سجّل حضوره في الوقت';
  await _show(id: name.hashCode & 0x7FFFFFFF, title: title, body: body,
      color: isLate ? const Color(0xFFFF9800) : const Color(0xFF4CAF50));
}

Future<void> showMobileCheckOut({required String name}) async {
  await initMobile();
  await _show(
      id: (name.hashCode + 1000) & 0x7FFFFFFF,
      title: '🚪 انصراف',
      body: '$name سجّل انصرافه',
      color: const Color(0xFF2196F3));
}

Future<void> showMobileAbsent({required String name}) async {
  await initMobile();
  await _show(
      id: (name.hashCode + 2000) & 0x7FFFFFFF,
      title: '🚫 غياب تلقائي',
      body: 'تم تسجيل $name كغائب لعدم كتابة عذر',
      color: const Color(0xFFF44336));
}

Future<void> showMobileExcuse({required String name, required String excuse}) async {
  await initMobile();
  await _show(
      id: (name.hashCode + 3000) & 0x7FFFFFFF,
      title: '📝 عذر جديد',
      body: '$name: $excuse',
      color: const Color(0xFF2196F3));
}

Future<void> _show({
  required int id,
  required String title,
  required String body,
  required Color color,
}) async {
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
