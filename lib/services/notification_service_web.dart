// services/notification_service_web.dart
// Web implementation using the browser Notification API
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:web/web.dart' as web;

bool _permissionGranted = false;

Future<void> initMobile() async {
  // Request notification permission from the browser
  try {
    final permission = web.Notification.permission;
    if (permission == 'granted') {
      _permissionGranted = true;
    } else if (permission != 'denied') {
      final result = await web.Notification.requestPermission().toDart;
      _permissionGranted = result.toDart == 'granted';
    }
  } catch (e) {
    // Notifications not supported in this browser
    _permissionGranted = false;
  }
}

void _showWebNotification({required String title, required String body}) {
  if (!_permissionGranted) return;
  try {
    final options = web.NotificationOptions(body: body, icon: 'icons/Icon-192.png');
    web.Notification(title, options);
  } catch (_) {}
}

Future<void> showMobileCheckIn({
  required String name,
  required bool isLate,
  required int minutesLate,
}) async {
  if (!_permissionGranted) await initMobile();
  final title = isLate ? '⚠️ تأخير في الحضور' : '✅ حضور جديد';
  final body = isLate
      ? '$name وصل متأخراً $minutesLate دقيقة'
      : '$name سجّل حضوره في الوقت';
  _showWebNotification(title: title, body: body);
}

Future<void> showMobileCheckOut({required String name}) async {
  _showWebNotification(title: '🚪 انصراف', body: '$name سجّل انصرافه');
}

Future<void> showMobileAbsent({required String name}) async {
  _showWebNotification(title: '🚫 غياب تلقائي', body: 'تم تسجيل $name كغائب');
}

Future<void> showMobileExcuse({required String name, required String excuse}) async {
  _showWebNotification(title: '📝 عذر جديد', body: '$name: $excuse');
}
