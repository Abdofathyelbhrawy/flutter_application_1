// screens/admin_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../utils/app_theme.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late int _shiftHour;    // العياده شفت 1
  late int _shiftMinute;
  bool _shift2Enabled = true;
  late int _shift2Hour;   // العياده شفت 2
  late int _shift2Minute;
  bool _shift3Enabled = true;
  late int _shift3Hour;   // المركز
  late int _shift3Minute;
  late int _lateThreshold;
  late int _absentAfter;
  
  bool _locationEnabled = false;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AttendanceProvider>();
    _shiftHour = p.shiftStartHour;
    _shiftMinute = p.shiftStartMinute;
    _shift2Enabled = p.shift2Enabled;
    _shift2Hour = p.shift2StartHour;
    _shift2Minute = p.shift2StartMinute;
    _shift3Enabled = p.shift3Enabled;
    _shift3Hour = p.shift3StartHour;
    _shift3Minute = p.shift3StartMinute;
    _lateThreshold = p.lateThresholdMinutes;
    _absentAfter = p.absentAfterMinutes;
    _locationEnabled = p.locationRestrictionEnabled;
  }

  Future<void> _save() async {
    await context.read<AttendanceProvider>().updateSettings(
      shiftStartHour: _shiftHour,
      shiftStartMinute: _shiftMinute,
      shift2Enabled: _shift2Enabled,
      shift2StartHour: _shift2Hour,
      shift2StartMinute: _shift2Minute,
      shift3Enabled: _shift3Enabled,
      shift3StartHour: _shift3Hour,
      shift3StartMinute: _shift3Minute,
      lateThresholdMinutes: _lateThreshold,
      absentAfterMinutes: _absentAfter,
      locationRestrictionEnabled: _locationEnabled,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('تم حفظ الإعدادات', textAlign: TextAlign.center),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    Navigator.pop(context);
  }
  
  Future<void> _addLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      // You might want to ask for a name dialog here
      await context.read<AttendanceProvider>().addCurrentLocation('موقع ${DateTime.now().minute}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إضافة الموقع بنجاح', textAlign: TextAlign.center), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: ${e.toString()}', textAlign: TextAlign.center), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _showManualLocationDialog() {
    final nameCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إضافة موقع بالإحداثيات', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             TextField(
              controller: nameCtrl,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'اسم الموقع (مثال: الفرع الرئيسي)',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppTheme.backgroundColor,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: latCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Latitude (خط العرض)',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppTheme.backgroundColor,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lngCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Longitude (خط الطول)',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppTheme.backgroundColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final lat = double.tryParse(latCtrl.text.trim());
              final lng = double.tryParse(lngCtrl.text.trim());

              if (name.isEmpty || lat == null || lng == null) {
                return;
              }

              // Capture context-dependent objects before async gap
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final provider = context.read<AttendanceProvider>();

              await provider.addManualLocation(name, lat, lng);
              nav.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('تم إضافة الموقع بنجاح', textAlign: TextAlign.center), backgroundColor: Colors.green),
              );
            },
            child: const Text('إضافة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final locations = provider.allowedLocations;

    return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.cardColor,
          title: const Text('الإعدادات', style: TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // -- Shift 1: always on --
                _SettingsCard(
                  title: 'وقت بداية الدوام',
                  subtitle: 'العياده - شفت 1 (دائماً مفعّل)',
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _NumberPicker(label: 'الساعة', value: _shiftHour, min: 0, max: 23, onChanged: (v) => setState(() => _shiftHour = v)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(':', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                        ),
                        _NumberPicker(label: 'الدقيقة', value: _shiftMinute, min: 0, max: 59, onChanged: (v) => setState(() => _shiftMinute = v)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // -- Shift 2: toggleable --
                _ShiftCard(
                  title: 'وقت بداية الدوام - العياده شفت 2',
                  enabled: _shift2Enabled,
                  onToggle: (v) => setState(() => _shift2Enabled = v),
                  hour: _shift2Hour,
                  minute: _shift2Minute,
                  onHourChanged: (v) => setState(() => _shift2Hour = v),
                  onMinuteChanged: (v) => setState(() => _shift2Minute = v),
                ),
                const SizedBox(height: 16),
                // -- Shift 3: المركز, toggleable --
                _ShiftCard(
                  title: 'وقت بداية الدوام - المركز',
                  enabled: _shift3Enabled,
                  onToggle: (v) => setState(() => _shift3Enabled = v),
                  hour: _shift3Hour,
                  minute: _shift3Minute,
                  onHourChanged: (v) => setState(() => _shift3Hour = v),
                  onMinuteChanged: (v) => setState(() => _shift3Minute = v),
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  title: 'حد التأخير (بالدقائق)',
                  subtitle: 'الحد الأقصى قبل إشعار الأدمن',
                  child: _NumberPicker(label: 'دقيقة', value: _lateThreshold, min: 1, max: 60, onChanged: (v) => setState(() => _lateThreshold = v)),
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  title: 'وقت الغياب التلقائي (بالدقائق)',
                  subtitle: 'إذا لم يكتب عذر خلال هذا الوقت من بداية الدوام',
                  child: _NumberPicker(label: 'دقيقة', value: _absentAfter, min: 10, max: 120, onChanged: (v) => setState(() => _absentAfter = v)),
                ),
                
                const SizedBox(height: 16),
                
                // Location Settings
                Container(
                  decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('تقييد الحضور بالموقع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                Text('السماح بالتسجيل فقط من مواقع محددة', style: TextStyle(color: Colors.white38, fontSize: 12)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _locationEnabled,
                            onChanged: (v) => setState(() => _locationEnabled = v),
                            activeThumbColor: AppTheme.primaryColor,
                          ),
                        ],
                      ),
                      if (_locationEnabled) ...[
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 8),
                        if (locations.isEmpty)
                          const Text('لا توجد مواقع مضافة. (لن يتمكن أحد من التسجيل!)', style: TextStyle(color: Colors.orange, fontSize: 12))
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: locations.length,
                            itemBuilder: (ctx, i) {
                              final loc = locations[i];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.location_on_rounded, color: Colors.blue),
                                title: Text(loc['name'] ?? 'موقع ${i+1}', style: const TextStyle(color: Colors.white)),
                                subtitle: Text('${loc['lat'].toStringAsFixed(4)}, ${loc['lng'].toStringAsFixed(4)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_rounded, color: Colors.red),
                                  onPressed: () => provider.removeLocation(i),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _isLoadingLocation ? null : _addLocation,
                          icon: _isLoadingLocation 
                             ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                             : const Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
                          label: Text(_isLoadingLocation ? 'جاري التحديد...' : 'أضف موقعي الحالي', style: const TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _showManualLocationDialog,
                          icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white70, size: 18),
                          label: const Text('أضف موقع بالإحداثيات', style: TextStyle(color: Colors.white70)),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded, color: Colors.white),
                  label: const Text('حفظ الإعدادات', style: TextStyle(fontSize: 16, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _showClearConfirm(context, todayOnly: true),
                  icon: const Icon(Icons.today_rounded, color: Colors.orange),
                  label: const Text('مسح سجلات اليوم فقط', style: TextStyle(color: Colors.orange)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _showClearConfirm(context, todayOnly: false),
                  icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
                  label: const Text('مسح كل السجلات', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  void _showClearConfirm(BuildContext context, {required bool todayOnly}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          todayOnly ? 'مسح سجلات اليوم' : 'مسح كل السجلات',
          style: TextStyle(color: todayOnly ? Colors.orange : Colors.red),
        ),
        content: Text(
          todayOnly
              ? 'هل تريد مسح سجلات اليوم فقط؟ لا يمكن التراجع.'
              : 'هل تريد مسح جميع السجلات بالكامل؟ لا يمكن التراجع!',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: todayOnly ? Colors.orange : Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (todayOnly) {
                context.read<AttendanceProvider>().clearToday();
              } else {
                context.read<AttendanceProvider>().clearAll();
              }
              Navigator.pop(ctx);
            },
            child: const Text('مسح', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _SettingsCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          if (subtitle != null) Text(subtitle!, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 12),
          Center(child: child),
        ],
      ),
    );
  }
}

class _NumberPicker extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _NumberPicker({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  Widget _btn({required bool isAdd, required bool enabled, required VoidCallback? onTap}) {
    final color = enabled ? Colors.white54 : Colors.white12;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withAlpha(30),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Icon(
          isAdd ? Icons.add_rounded : Icons.remove_rounded,
          color: color,
          size: 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(isAdd: false, enabled: value > min, onTap: () => onChanged(value - 1)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value.toString().padLeft(2, '0'),
                  style: const TextStyle(color: AppTheme.primaryColor, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _btn(isAdd: true, enabled: value < max, onTap: () => onChanged(value + 1)),
        ],
      ),
    );
  }
}

/// A shift card with an enable/disable toggle.
/// When [enabled] is false the time picker is hidden and the card is dimmed.
class _ShiftCard extends StatelessWidget {
  final String title;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final int hour;
  final int minute;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  const _ShiftCard({
    required this.title,
    required this.enabled,
    required this.onToggle,
    required this.hour,
    required this.minute,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled ? AppTheme.primaryColor.withAlpha(80) : Colors.white10,
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: enabled ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: onToggle,
                  activeThumbColor: AppTheme.primaryColor,
                ),
              ],
            ),
            if (enabled) ...[
              const SizedBox(height: 10),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _NumberPicker(label: 'الساعة', value: hour, min: 0, max: 23, onChanged: onHourChanged),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(':', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      ),
                      _NumberPicker(label: 'الدقيقة', value: minute, min: 0, max: 59, onChanged: onMinuteChanged),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              const Center(
                child: Text('معطّل — لن يُستخدم هذا الشفت', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
