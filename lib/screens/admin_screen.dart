// screens/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import '../models/attendance_record.dart';
import '../utils/app_theme.dart';
import '../services/notification_service.dart';
import 'admin_settings_screen.dart';
import 'excuse_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _passController = TextEditingController();
  bool _obscure = true;
  String _error = '';
  static const _adminPassword = 'admin123';

  @override
  void dispose() {
    _passController.dispose();
    super.dispose();
  }

  void _login() {
    if (_passController.text == _adminPassword) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
    } else {
      setState(() => _error = 'كلمة المرور غير صحيحة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.primaryGradient),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 60),
                ),
                const SizedBox(height: 24),
                const Text('لوحة تحكم الأدمن', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('مركز الأشعة', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 40),
                TextField(
                  controller: _passController,
                  obscureText: _obscure,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, letterSpacing: 4),
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    hintText: 'كلمة المرور',
                    hintStyle: TextStyle(color: Colors.white.withAlpha(102), letterSpacing: 0),
                    filled: true,
                    fillColor: AppTheme.cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_error, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('دخول', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    NotificationService().showNotifications = true;
  }

  @override
  void dispose() {
    NotificationService().showNotifications = false;
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final unreadCount = provider.unreadNotifications.length;

    return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.cardColor,
          title: const Text('لوحة التحكم', style: TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_rounded, color: Colors.white70),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSettingsScreen())),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primaryColor,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              const Tab(text: 'السجل الكامل', icon: Icon(Icons.list_alt_rounded)),
              Tab(
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount'),
                  child: const Icon(Icons.notifications_rounded),
                ),
                text: 'الإشعارات',
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            _StatsBar(provider: provider),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _AllRecordsTab(provider: provider),
                  _NotificationsTab(provider: provider),
                ],
              ),
            ),
          ],
        ),
      );
  }
}

class _StatsBar extends StatelessWidget {
  final AttendanceProvider provider;
  const _StatsBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final stats = provider.todayStats;
    final total = provider.todayRecords.length;
    return Container(
      color: AppTheme.cardColor,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MiniStat(count: total, label: 'الكل', color: Colors.white70),
          _MiniStat(count: stats['present']!, label: 'حاضر', color: Colors.green),
          _MiniStat(count: stats['late']!, label: 'متأخر', color: Colors.orange),
          _MiniStat(count: stats['lateWithExcuse']!, label: 'بعذر', color: Colors.blue),
          _MiniStat(count: stats['absent']!, label: 'غائب', color: Colors.red),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _MiniStat({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$count', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: color.withAlpha(179), fontSize: 11)),
      ],
    );
  }
}

class _AllRecordsTab extends StatelessWidget {
  final AttendanceProvider provider;
  const _AllRecordsTab({required this.provider});

  /// حساب دقائق التأخير الحقيقية بناءً على وقت الشيفت الصحيح
  int _computeMinutesLate(AttendanceRecord r) {
    final shiftStart = provider.shiftStartForDay(r.checkInTime, r.locationName);
    final graceEnd = shiftStart.add(Duration(minutes: provider.lateThresholdMinutes));
    if (!r.checkInTime.isAfter(graceEnd)) return 0;
    return r.checkInTime.difference(shiftStart).inMinutes;
  }

  String _statusLabel(AttendanceRecord r) {
    switch (r.status) {
      case AttendanceStatus.present: return 'حاضر';
      case AttendanceStatus.late: return 'متأخر ${AppTheme.formatLateTime(_computeMinutesLate(r))}';
      case AttendanceStatus.lateWithExcuse: return 'متأخر بعذر';
      case AttendanceStatus.lateExcusePending: return 'عذر معلق';
      case AttendanceStatus.absent: return 'غياب';
      case AttendanceStatus.checkedOut: return 'انصرف';
    }
  }

  Color _statusColor(AttendanceRecord r) {
    switch (r.status) {
      case AttendanceStatus.present:
      case AttendanceStatus.checkedOut: return Colors.green;
      case AttendanceStatus.late: return Colors.orange;
      case AttendanceStatus.lateWithExcuse: return Colors.blue;
      case AttendanceStatus.lateExcusePending: return Colors.purple;
      case AttendanceStatus.absent: return Colors.red;
    }
  }

  String _arabicDate(String dateKey) {
    final parts = dateKey.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    return DateFormat('EEEE، d MMMM yyyy', 'ar').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final byDate = provider.recordsByDate;
    if (byDate.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text('لا توجد سجلات بعد', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }
    final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dates.length,
      itemBuilder: (ctx, di) {
        final dateKey = dates[di];
        final dayRecords = byDate[dateKey]!;
        final isToday = dateKey == todayKey;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date header
            Container(
              margin: EdgeInsets.only(bottom: 8, top: di == 0 ? 0 : 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isToday ? AppTheme.primaryGradient : null,
                color: isToday ? null : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      color: isToday ? Colors.white : Colors.white54, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isToday ? 'اليوم — ${_arabicDate(dateKey)}' : _arabicDate(dateKey),
                      style: TextStyle(
                        color: isToday ? Colors.white : Colors.white70,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text('${dayRecords.length} موظف',
                      style: TextStyle(
                          color: isToday ? Colors.white70 : Colors.white38,
                          fontSize: 11)),
                ],
              ),
            ),
            // Records for this date
            ...dayRecords.map((r) {
              final color = _statusColor(r);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withAlpha(77)),
                ),
                child: ExpansionTile(
                  collapsedBackgroundColor: Colors.transparent,
                  backgroundColor: Colors.transparent,
                  leading: CircleAvatar(
                    backgroundColor: color.withAlpha(51),
                    child: Text(r.name.isNotEmpty ? r.name[0] : '؟',
                        style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(r.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.login_rounded, color: Colors.white38, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('hh:mm a', 'ar').format(r.checkInTime),
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.calendar_today_rounded, color: Colors.white24, size: 11),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              DateFormat('EEEE، d MMM yyyy', 'ar').format(r.checkInTime),
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (r.locationName != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: Colors.lightBlueAccent, size: 13),
                            const SizedBox(width: 3),
                            Text(
                              r.locationName!,
                              style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: color.withAlpha(51),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(_statusLabel(r),
                        style: TextStyle(color: color, fontSize: 11)),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (r.checkOutTime != null)
                            _InfoRow(
                                icon: Icons.logout_rounded,
                                label: 'انصراف',
                                value: DateFormat('hh:mm a', 'ar')
                                    .format(r.checkOutTime!)),
                          if ((r.status == AttendanceStatus.late || r.status == AttendanceStatus.lateWithExcuse || r.status == AttendanceStatus.lateExcusePending))
                            Builder(builder: (context) {
                              final mins = _computeMinutesLate(r);
                              if (mins <= 0) return const SizedBox.shrink();
                              return _InfoRow(
                                  icon: Icons.timer_rounded,
                                  label: 'مدة التأخير',
                                  value: AppTheme.formatLateTime(mins),
                                  valueColor: Colors.orange);
                            }),
                          if (r.excuse != null)
                            _InfoRow(
                                icon: Icons.description_rounded,
                                label: 'العذر',
                                value: r.excuse!,
                                valueColor: Colors.blue),
                          if (r.status == AttendanceStatus.lateExcusePending) ...[
                             _InfoRow(
                                icon: Icons.hourglass_top_rounded,
                                label: 'الحالة',
                                value: 'في انتظار الموافقة',
                                valueColor: Colors.orange),
                             const SizedBox(height: 12),
                             Row(
                               children: [
                                 Expanded(
                                   child: ElevatedButton.icon(
                                     onPressed: () => provider.justifyExcuse(r.id, true),
                                     icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                     label: const Text('قبول العذر', style: TextStyle(color: Colors.white)),
                                     style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 Expanded(
                                   child: ElevatedButton.icon(
                                     onPressed: () => provider.justifyExcuse(r.id, false),
                                     icon: const Icon(Icons.cancel_rounded, color: Colors.white, size: 18),
                                     label: const Text('رفض (غياب)', style: TextStyle(color: Colors.white)),
                                     style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                   ),
                                 ),
                               ],
                             ),
                          ] else if (r.status == AttendanceStatus.late) ...[
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => ExcuseScreen(record: r))),
                              icon: const Icon(Icons.edit_note_rounded,
                                  color: Colors.white, size: 18),
                              label: const Text('إضافة عذر (أدمن)',
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}


class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Expanded(
            child: Text(value, style: TextStyle(color: valueColor ?? Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _NotificationsTab extends StatelessWidget {
  final AttendanceProvider provider;
  const _NotificationsTab({required this.provider});

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.cardColor,
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 26),
            SizedBox(width: 8),
            Text('مسح الإشعارات', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'سيتم حذف جميع الإشعارات نهائياً.المتابعة لن تتمكن من استعادتها.',
          style: TextStyle(color: Colors.white70, height: 1.5),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 18),
            label: const Text('مسح الكل', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await provider.clearAllNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifs = provider.adminNotifications;
    if (notifs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_rounded, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text('لا توجد إشعارات', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (provider.unreadNotifications.isNotEmpty)
                TextButton.icon(
                  onPressed: provider.markAllNotificationsRead,
                  icon: const Icon(Icons.done_all_rounded, color: Colors.blue, size: 18),
                  label: const Text('تحديد الكل كمقروء', style: TextStyle(color: Colors.blue)),
                )
              else
                const SizedBox.shrink(),
              TextButton.icon(
                onPressed: () => _confirmClearAll(context),
                icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 18),
                label: const Text('مسح الكل', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: notifs.length,
            itemBuilder: (ctx, i) => _NotificationTile(
              notification: notifs[i],
              onTap: () => provider.markNotificationRead(notifs[i]['id'] as String),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = notification['type'] as String;
    final name = notification['name'] as String;
    final time = DateTime.parse(notification['time'] as String);
    final minutesLate = notification['minutesLate'] as int;
    final isRead = notification['read'] as bool;

    Color color;
    IconData icon;
    String title;
    String subtitle;

    switch (type) {
      case 'arrival':
        color = Colors.green;
        icon = Icons.login_rounded;
        title = 'حضور في الوقت';
        subtitle = 'وصل $name في الوقت المحدد';
        break;
      case 'late_arrival':
        color = Colors.orange;
        icon = Icons.access_time_rounded;
        title = 'تأخير ⚠️';
        subtitle = 'وصل $name متأخراً ${AppTheme.formatLateTime(minutesLate)}';
        break;
      case 'auto_absent':
        color = Colors.red;
        icon = Icons.person_off_rounded;
        title = 'غياب تلقائي 🚫';
        subtitle = 'تم تسجيل $name كغائب لعدم كتابة عذر';
        break;
      default:
        color = Colors.grey;
        icon = Icons.info_rounded;
        title = 'إشعار';
        subtitle = name;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? AppTheme.cardColor : color.withAlpha(26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isRead ? Colors.white12 : color.withAlpha(102)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withAlpha(51), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                      if (!isRead) ...[
                        const SizedBox(width: 6),
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      ],
                    ],
                  ),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text(DateFormat('hh:mm a', 'ar').format(time), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
