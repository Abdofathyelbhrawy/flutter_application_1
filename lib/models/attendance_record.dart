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
  bool notificationSent;
  String? locationName;
  final int minutesLate; // مُخزَّن لحظة التسجيل بناءً على وقت الشيفت الفعلي

  AttendanceRecord({
    String? id,
    required this.name,
    required this.checkInTime,
    this.checkOutTime,
    this.status = AttendanceStatus.present,
    this.excuse,
    this.notificationSent = false,
    this.locationName,
    this.minutesLate = 0,
  }) : id = id ?? Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'checkInTime': checkInTime.toIso8601String(),
    'checkOutTime': checkOutTime?.toIso8601String(),
    'status': status.index,
    'excuse': excuse,
    'notificationSent': notificationSent,
    'locationName': locationName,
    'minutesLate': minutesLate,
  };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String,
      name: json['name'] as String,
      checkInTime: DateTime.parse(json['checkInTime'] as String),
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.parse(json['checkOutTime'] as String)
          : null,
      status: AttendanceStatus.values[json['status'] as int],
      excuse: json['excuse'] as String?,
      notificationSent: (json['notificationSent'] as bool?) ?? false,
      locationName: json['locationName'] as String?,
      minutesLate: (json['minutesLate'] as int?) ?? 0,
    );
  }
}
