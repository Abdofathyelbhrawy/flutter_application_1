// screens/checkin_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import '../models/attendance_record.dart';
import '../utils/app_theme.dart';
import 'excuse_screen.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();

    // Pulse on the check-in button
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Fade + slide-up entrance
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // Live clock — tick every second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleCheckIn() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('من فضلك اكتب اسمك', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    final provider = context.read<AttendanceProvider>();
    final result = await provider.checkIn(name);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result == 'already_in') {
      _showSnackBar('⚠️ أنت مسجّل حضور بالفعل اليوم', Colors.orange);
      return;
    } else if (result == 'location_disabled') {
      _showSnackBar('❌ يجب تفعيل خدمة الموقع (GPS) لتسجيل الحضور', Colors.red);
      return;
    } else if (result == 'permission_denied') {
      _showSnackBar('❌ يجب إعطاء صلاحية الموقع للتطبيق', Colors.red);
      return;
    } else if (result == 'permission_denied_forever') {
      _showSnackBar('❌ صلاحية الموقع مرفوضة نهائياً. قم بتفعيلها من الإعدادات', Colors.red);
      return;
    } else if (result == 'out_of_range') {
      _showSnackBar('❌ أنت خارج النطاق المسموح به للحضور (بعيد عن المركز)', Colors.red);
      return;
    }

    final record = provider.getTodayRecord(name);
    if (record == null) return;

    if (result == 'late') {
      await _showLateDialog(record);
    } else {
      _showSuccessDialog(name);
    }
    _nameController.clear();
  }

  Future<void> _showLateDialog(AttendanceRecord record) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.cardColor,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
            SizedBox(width: 8),
            Text('تأخير', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'أنت متأخر ${AppTheme.formatLateTime(record.minutesLate)}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'هل تريد كتابة عذر للتأخير؟\nإذا لم تكتب عذراً سيُسجّل غياب تلقائياً',
              style: TextStyle(color: Colors.orange, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لاحقاً', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (!mounted) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => ExcuseScreen(record: record)));
            },
            child: const Text('اكتب عذر الآن', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.cardColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 60),
            const SizedBox(height: 16),
            Text(
              'أهلاً $name 👋',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'تم تسجيل حضورك بنجاح\n${DateFormat('hh:mm a', 'ar').format(DateTime.now())}',
              style: const TextStyle(color: Colors.white60),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('شكراً', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm:ss a', 'ar').format(_now);
    final dateStr = DateFormat('EEEE، d MMMM yyyy', 'ar').format(_now);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withAlpha(77),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 48),
                        const SizedBox(height: 8),
                        const Text(
                          'مركز الأشعة',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'نظام الحضور والانصراف',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        // Live clock with smooth second ticking
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            timeStr,
                            key: ValueKey(timeStr),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        Text(dateStr, style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Check-in card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(51),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'تسجيل الحضور',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _nameController,
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'اكتب اسمك هنا...',
                            hintStyle: TextStyle(color: Colors.white.withAlpha(102)),
                            prefixIcon: const Icon(Icons.person_rounded, color: Colors.white54),
                            filled: true,
                            fillColor: AppTheme.backgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _handleCheckIn,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.login_rounded, color: Colors.white),
                            label: Text(
                              _isLoading ? 'جارٍ التسجيل...' : 'تسجيل الحضور',
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
