// services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance_record.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  // --- Attendance Records ---

  Future<void> insertRecord(AttendanceRecord record) async {
    await _supabase.from('attendance_records').insert({
      'id': record.id,
      'name': record.name,
      'check_in_time': record.checkInTime.toUtc().toIso8601String(),
      'check_out_time': record.checkOutTime?.toUtc().toIso8601String(),
      'status': record.status.index,
      'excuse': record.excuse,
      'minutes_late': record.minutesLate,
      'location_name': record.locationName,
    });
  }

  Future<void> updateRecord(AttendanceRecord record) async {
    await _supabase
        .from('attendance_records')
        .update({
          'check_out_time': record.checkOutTime?.toUtc().toIso8601String(),
          'status': record.status.index,
          'excuse': record.excuse,
        })
        .eq('id', record.id);
  }

  Stream<List<AttendanceRecord>> streamRecords() {
    return _supabase
        .from('attendance_records')
        .stream(primaryKey: ['id'])
        .order('check_in_time', ascending: false) // Newest first
        .map(
          (data) => data.map((json) {
            return AttendanceRecord(
              id: json['id'],
              name: json['name'],
              checkInTime: DateTime.parse(json['check_in_time']).toLocal(),
              checkOutTime: json['check_out_time'] != null
                  ? DateTime.parse(json['check_out_time']).toLocal()
                  : null,
              status: AttendanceStatus.values[json['status']],
              excuse: json['excuse'],
              locationName: json['location_name'] as String?,
              minutesLate: (json['minutes_late'] as int?) ?? 0,
            );
          }).toList(),
        );
  }

  // Clear all records (Manual Admin Action)
  Future<void> clearAllRecords() async {
    // You must have RLS policies allowing delete or use service role key if on backend
    // Assuming anon key has delete permission for this demo/internal app
    await _supabase.from('attendance_records').delete().neq('id', '0');
  }


  Future<void> deleteRecords(List<String> ids) async {
    if (ids.isEmpty) return;
    await _supabase.from('attendance_records').delete().inFilter('id', ids);
  }

  // --- Notifications ---

  Future<void> insertNotification(Map<String, dynamic> notif) async {
    await _supabase.from('admin_notifications').insert({
      'id': notif['id'],
      'type': notif['type'],
      'name': notif['name'],
      'time': notif['time'],
      'minutes_late': notif['minutesLate'],
      'record_id': notif['recordId'],
      'is_read': notif['read'],
    });
  }

  // --- Settings ---

  Future<void> saveSetting(String key, String value) async {
    await _supabase.from('app_settings').upsert({'key': key, 'value': value});
  }

  Future<Map<String, String>> loadSettings() async {
    final response = await _supabase.from('app_settings').select();
    final Map<String, String> settings = {};
    for (final row in response) {
      settings[row['key']] = row['value'];
    }
    return settings;
  }

  Stream<Map<String, String>> streamSettings() {
    return _supabase
        .from('app_settings')
        .stream(primaryKey: ['key'])
        .map((rows) {
          final Map<String, String> settings = {};
          for (final row in rows) {
            settings[row['key'] as String] = row['value'] as String;
          }
          return settings;
        });
  }
}
