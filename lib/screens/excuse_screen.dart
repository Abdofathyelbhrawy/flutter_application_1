import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/attendance_record.dart';
import '../providers/attendance_provider.dart';
import '../utils/app_theme.dart';

class ExcuseScreen extends StatefulWidget {
  final AttendanceRecord record;
  const ExcuseScreen({super.key, required this.record});

  @override
  State<ExcuseScreen> createState() => _ExcuseScreenState();
}

class _ExcuseScreenState extends State<ExcuseScreen> {
  final _excuseController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _excuseController.dispose();
    super.dispose();
  }

  Future<void> _submitExcuse() async {
    final excuse = _excuseController.text.trim();
    if (excuse.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('من فضلك اكتب عذرك', textAlign: TextAlign.center),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    await context.read<AttendanceProvider>().submitExcuse(widget.record.id, excuse);
    if (!mounted) return;
    setState(() => _isLoading = false);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.cardColor,
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.blue, size: 60),
            SizedBox(height: 16),
            Text(
              'تم إرسال العذر بنجاح',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'تم تسجيل عذرك وإبلاغ الإدارة',
              style: TextStyle(color: Colors.white60),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('حسناً', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.cardColor,
          title: const Text('كتابة عذر التأخير', style: TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(26),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.withAlpha(77)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.record.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('تأخير ${AppTheme.formatLateTime(widget.record.minutesLate)}', style: const TextStyle(color: Colors.orange)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('اكتب سبب التأخير:', style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                  controller: _excuseController,
                  textAlign: TextAlign.right,
                  maxLines: 5,
                  cursorColor: Colors.blue,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'مثال: كان فيه زحمة / موعد عند الطبيب...',
                    hintStyle: TextStyle(color: Colors.white.withAlpha(102)),
                    filled: true,
                    fillColor: AppTheme.cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitExcuse,
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white),
                  label: Text(
                    _isLoading ? 'جارٍ الإرسال...' : 'إرسال العذر',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withAlpha(77)),
                  ),
                  child: const Text(
                    '⚠️ إذا لم تكتب عذراً سيتم تسجيلك كغائب تلقائياً',
                    style: TextStyle(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}
