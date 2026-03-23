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
  // Old shift variables removed

  late int _lateThreshold;
  late int _absentAfter;

  bool _locationEnabled = false;
  bool _isLoadingLocation = false;

  // ---- helpers ----
  /// تحويل 24h → 12h display + isPm
  static (int, bool) _to12(int h24) {
    final isPm = h24 >= 12;
    var h12 = h24 % 12;
    if (h12 == 0) h12 = 12;
    return (h12, isPm);
  }

  /// تحويل 12h + isPm → 24h
  static int _to24(int h12, bool isPm) {
    if (isPm) {
      return h12 == 12 ? 12 : h12 + 12;
    } else {
      return h12 == 12 ? 0 : h12;
    }
  }

  @override
  void initState() {
    super.initState();
    final p = context.read<AttendanceProvider>();
    _lateThreshold   = p.lateThresholdMinutes;
    _absentAfter     = p.absentAfterMinutes;
    _locationEnabled = p.locationRestrictionEnabled;
  }

  Future<void> _save() async {
    await context.read<AttendanceProvider>().updateSettings(
      lateThresholdMinutes:      _lateThreshold,
      absentAfterMinutes:        _absentAfter,
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
              decoration: InputDecoration(
                hintText: 'اسم الموقع (مثال: الفرع الرئيسي)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: latCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Latitude (خط العرض)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lngCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Longitude (خط الطول)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
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

  Future<void> _addShiftToLocation(int locIndex) async {
    final provider = context.read<AttendanceProvider>();
    final List<Map<String, dynamic>> updatedLocations = List.from(provider.allowedLocations.map((e) => Map<String, dynamic>.from(e)));
    var shifts = updatedLocations[locIndex]['shifts'];
    if (shifts == null) {
      shifts = [];
      updatedLocations[locIndex]['shifts'] = shifts;
    }
    // Default new shift: 9:00 AM
    (shifts as List).add({'hour': 9, 'minute': 0});
    await provider.updateSettings(allowedLocations: updatedLocations);
  }

  Future<void> _removeShiftFromLocation(int locIndex, int shiftIndex) async {
    final provider = context.read<AttendanceProvider>();
    final List<Map<String, dynamic>> updatedLocations = List.from(provider.allowedLocations.map((e) => Map<String, dynamic>.from(e)));
    var shifts = updatedLocations[locIndex]['shifts'] as List;
    shifts.removeAt(shiftIndex);
    await provider.updateSettings(allowedLocations: updatedLocations);
  }

  Future<void> _updateShiftTime(int locIndex, int shiftIndex, int newHour24, int newMin) async {
    final provider = context.read<AttendanceProvider>();
    final List<Map<String, dynamic>> updatedLocations = List.from(provider.allowedLocations.map((e) => Map<String, dynamic>.from(e)));
    var shifts = updatedLocations[locIndex]['shifts'] as List;
    shifts[shiftIndex] = {'hour': newHour24, 'minute': newMin};
    await provider.updateSettings(allowedLocations: updatedLocations);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final locations = provider.allowedLocations;

    return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.backgroundColor,
          title: const Text('الإعدادات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                // Removed old static shift cards
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
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.location_on_rounded, color: Colors.blue),
                                    title: Text(loc['name'] ?? 'موقع ${i+1}', style: const TextStyle(color: Colors.white)),
                                    subtitle: Text('${loc['lat'].toStringAsFixed(4)}, ${loc['lng'].toStringAsFixed(4)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_rounded, color: Colors.red),
                                      onPressed: () => provider.removeLocation(i),
                                    ),
                                  ),
                                  // Shifts for this location
                                  Builder(
                                    builder: (ctx) {
                                      final shifts = (loc['shifts'] as List<dynamic>?) ?? [];
                                      return Column(
                                        children: [
                                          for (int sIdx = 0; sIdx < shifts.length; sIdx++) ...[
                                            Builder(
                                              builder: (innerCtx) {
                                                final shift = shifts[sIdx];
                                                final s24 = _to12(shift['hour'] as int);
                                                return Padding(
                                                  padding: const EdgeInsets.only(right: 32, bottom: 8),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          alignment: Alignment.centerRight,
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.start,
                                                            children: [
                                                              _NumberPicker(
                                                                label: 'الساعة',
                                                                value: s24.$1,
                                                                min: 1,
                                                                max: 12,
                                                                onChanged: (v) => _updateShiftTime(i, sIdx, _to24(v, s24.$2), shift['minute'] as int),
                                                              ),
                                                              const Padding(
                                                                padding: EdgeInsets.symmetric(horizontal: 6),
                                                                child: Text(':', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                                              ),
                                                              _NumberPicker(
                                                                label: 'الدقيقة',
                                                                value: shift['minute'] as int,
                                                                min: 0,
                                                                max: 59,
                                                                onChanged: (v) => _updateShiftTime(i, sIdx, shift['hour'] as int, v),
                                                              ),
                                                              const SizedBox(width: 8),
                                                              _AmPmToggle(
                                                                isPm: s24.$2,
                                                                onChanged: (v) => _updateShiftTime(i, sIdx, _to24(s24.$1, v), shift['minute'] as int),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red),
                                                        onPressed: () => _removeShiftFromLocation(i, sIdx),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }
                                            ),
                                          ],
                                          // Add shift button
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton.icon(
                                              onPressed: () => _addShiftToLocation(i),
                                              icon: const Icon(Icons.add_alarm_rounded, color: Colors.orange, size: 16),
                                              label: const Text('إضافة موعد دوام', style: TextStyle(color: Colors.orange, fontSize: 12)),
                                            ),
                                          ),
                                          const Divider(color: Colors.white10),
                                        ],
                                      );
                                    }
                                  ),
                                ],
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

                const SizedBox(height: 16),

                // Device Bindings Management
                Container(
                  decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.devices_rounded, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('الأجهزة المربوطة للموظفين', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('يمكنك فك ارتباط جهاز الموظف ليتمكن من الدخول من متصفح/هاتف جديد.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      const Divider(color: Colors.white10, height: 24),
                      if (provider.deviceBindings.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('لا توجد أجهزة مربوطة حالياً.', style: TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic)),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: provider.deviceBindings.length,
                          itemBuilder: (ctx, i) {
                            final entry = provider.deviceBindings.entries.elementAt(i);
                            final empName = entry.key;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange.withAlpha(40),
                                  child: const Icon(Icons.person_rounded, color: Colors.orange, size: 20),
                                ),
                                title: Text(empName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: const Text('جهاز مربوط', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                trailing: TextButton.icon(
                                  onPressed: () {
                                    // Confirm and unbind
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: AppTheme.cardColor,
                                        title: const Text('فك ارتباط الجهاز', style: TextStyle(color: Colors.white)),
                                        content: Text('هل أنت متأكد من فك ارتباط جهاز الموظف ($empName)؟ سيتمكن من تسجيل الدخول من جهاز جديد.', style: const TextStyle(color: Colors.white70)),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
                                          ElevatedButton(
                                            onPressed: () {
                                              provider.unbindDevice(empName);
                                              Navigator.pop(ctx);
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم فك ارتباط جهاز $empName بنجاح.', textAlign: TextAlign.center), backgroundColor: Colors.green));
                                            },
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                            child: const Text('فك الارتباط', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.link_off_rounded, color: Colors.orange, size: 16),
                                  label: const Text('فك', style: TextStyle(color: Colors.orange, fontSize: 12)),
                                ),
                              ),
                            );
                          },
                        ),
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



/// زر AM / PM يُبدَّل بين الصباح والمساء
class _AmPmToggle extends StatelessWidget {
  final bool isPm;
  final ValueChanged<bool> onChanged;
  const _AmPmToggle({required this.isPm, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Seg(label: 'AM', active: !isPm, onTap: () => onChanged(false)),
        const SizedBox(height: 4),
        _Seg(label: 'PM', active: isPm,  onTap: () => onChanged(true)),
      ],
    );
  }
}

class _Seg extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Seg({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryColor : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppTheme.primaryColor : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white38,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}


