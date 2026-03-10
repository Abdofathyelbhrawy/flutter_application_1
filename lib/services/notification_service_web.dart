// services/notification_service_web.dart
// Web stub — all notification functions are no-ops on web

Future<void> initMobile() async {}

Future<void> showMobileCheckIn({
  required String name,
  required bool isLate,
  required int minutesLate,
}) async {}

Future<void> showMobileCheckOut({required String name}) async {}

Future<void> showMobileAbsent({required String name}) async {}

Future<void> showMobileExcuse({required String name, required String excuse}) async {}
