// models/attendance_record.dart
import 'package:uuid/uuid.dart';

enum AttendanceStatus {
  present,         // حضور في الوقت
  late,            // متأخر
  lateWithExcuse,  // متأخر بعذر
  absent,          // غياب
  checkedOut,      // انصرف
  lateExcusePending, // عذر قيد الانتظار
}

class AttendanceRecord {
  final String id;
  final String name;
  final DateTime checkInTime;
  DateTime? checkOutTime;
  AttendanceStatus status;
  String? excuse;
  String? locationName;
  final int minutesLate; // مُخزَّن لحظة التسجيل بناءً على وقت الشيفت الفعلي

  AttendanceRecord({
    String? id,
    required this.name,
    required this.checkInTime,
    this.checkOutTime,
    this.status = AttendanceStatus.present,
    this.excuse,
    this.locationName,
    this.minutesLate = 0,
  }) : id = id ?? Uuid().v4();
}
