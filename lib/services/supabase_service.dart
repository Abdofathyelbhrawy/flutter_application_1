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
      'check_in_time': record.checkInTime.toIso8601String(),
      'check_out_time': record.checkOutTime?.toIso8601String(),
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
          'check_out_time': record.checkOutTime?.toIso8601String(),
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

  // Clear today's records (Manual Admin Action)
  Future<void> clearTodayRecords() async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    // Delete records where check_in_time starts with today's date
    await _supabase
        .from('attendance_records')
        .delete()
        .gte('check_in_time', '${todayStr}T00:00:00')
        .lt('check_in_time', '${todayStr}T23:59:59');
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

  Stream<List<Map<String, dynamic>>> streamNotifications() {
    return _supabase
        .from('admin_notifications')
        .stream(primaryKey: ['id'])
        .order('time', ascending: false)
        .map(
          (data) => data.map((json) {
            return {
              'id': json['id'],
              'type': json['type'],
              'name': json['name'],
              'time': json['time'],
              'minutesLate': json['minutes_late'],
              'recordId': json['record_id'],
              'read': json['is_read'],
            };
          }).toList(),
        );
  }

  Future<void> markNotificationRead(String id) async {
    await _supabase
        .from('admin_notifications')
        .update({'is_read': true})
        .eq('id', id);
  }

  Future<void> markAllNotificationsRead(List<String> ids) async {
    if (ids.isEmpty) return;
    await _supabase
        .from('admin_notifications')
        .update({'is_read': true})
        .inFilter('id', ids);
  }

  Future<void> clearAllNotifications() async {
    await _supabase.from('admin_notifications').delete().neq('id', '');
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

  /// بث real-time للإعدادات — يُطلق عند كل تغيير في جدول app_settings
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

