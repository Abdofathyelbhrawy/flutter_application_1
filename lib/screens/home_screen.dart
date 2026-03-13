// screens/home_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../utils/app_theme.dart';
import 'checkin_screen.dart';
import 'checkout_screen.dart';
import 'admin_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _locationGranted = false; // tracks whether location is available

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestLocationPermission());
  }

  Future<void> _requestLocationPermission() async {
    // On web, the browser handles location permission at request time
    if (kIsWeb) {
      setState(() => _locationGranted = true);
      return;
    }

    // 1. Check GPS
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() => _locationGranted = false);
      await _showGpsDialog();
      return;
    }

    // 2. Check / request permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (!mounted) return;

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _locationGranted = false);
      _showPermissionDeniedDialog(permanent: permission == LocationPermission.deniedForever);
    } else {
      setState(() => _locationGranted = true);
    }
  }

  Future<void> _showGpsDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.cardColor,
        title: const Row(
          children: [
            Icon(Icons.location_off_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('الموقع مُعطَّل', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'يحتاج التطبيق إلى خدمة الموقع (GPS) لتحديد الفرع عند تسجيل الحضور.\n\nمن فضلك قم بتشغيل الموقع من الإعدادات ثم افتح التطبيق مجدداً.',
          style: TextStyle(color: Colors.white70, height: 1.5),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لاحقاً', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openLocationSettings();
            },
            icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
            label: const Text('فتح الإعدادات', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog({required bool permanent}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.cardColor,
        title: const Row(
          children: [
            Icon(Icons.location_disabled_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('صلاحية الموقع مرفوضة', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          permanent
              ? 'تم رفض صلاحية الموقع بشكل دائم.\n\nادخل على إعدادات التطبيق وفعّل صلاحية الموقع يدوياً حتى يعمل التطبيق بشكل صحيح.'
              : 'صلاحية الموقع ضرورية لتحديد الفرع عند تسجيل الحضور.\n\nالرجاء السماح للتطبيق باستخدام الموقع.',
          style: const TextStyle(color: Colors.white70, height: 1.5),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً', style: TextStyle(color: Colors.grey)),
          ),
          if (permanent)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await Geolocator.openAppSettings();
              },
              icon: const Icon(Icons.app_settings_alt_rounded, color: Colors.white, size: 18),
              label: const Text('إعدادات التطبيق', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final unreadCount = provider.unreadNotifications.length;

    // Pages: swap checkin/checkout with blocker if location not granted
    final List<Widget> pages = [
      _locationGranted ? const CheckInScreen() : _LocationBlockedScreen(onRetry: _requestLocationPermission),
      _locationGranted ? const CheckOutScreen() : _LocationBlockedScreen(onRetry: _requestLocationPermission),
      const AdminLoginScreen(),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          border: Border(top: BorderSide(color: Colors.white.withAlpha(15), width: 1.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(77), blurRadius: 10, offset: const Offset(0, -4))
          ],
        ),
        child: Row(
          children: [
            _NavItem(
              icon: Icons.fingerprint_rounded,
              label: 'تسجيل الحضور',
              selected: _selectedIndex == 0,
              onTap: () => setState(() => _selectedIndex = 0),
            ),
            _NavItem(
              icon: Icons.exit_to_app_rounded,
              label: 'انصراف',
              selected: _selectedIndex == 1,
              onTap: () => setState(() => _selectedIndex = 1),
            ),
            _NavItem(
              icon: Icons.admin_panel_settings_rounded,
              label: 'الأدمن',
              selected: _selectedIndex == 2,
              badge: unreadCount > 0 ? '$unreadCount' : null,
              onTap: () => setState(() => _selectedIndex = 2),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Blocking screen shown when location is denied ───────────────────────────
class _LocationBlockedScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const _LocationBlockedScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_off_rounded, color: Colors.orange, size: 64),
              ),
              const SizedBox(height: 24),
              const Text(
                'الموقع غير مُفعَّل',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'يجب تفعيل خدمة الموقع (GPS) والسماح للتطبيق باستخدامه لتتمكن من تسجيل الحضور والانصراف.',
                style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Geolocator.openLocationSettings(),
                icon: const Icon(Icons.settings_rounded, color: Colors.white54, size: 18),
                label: const Text('فتح إعدادات الموقع', style: TextStyle(color: Colors.white54)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated bottom nav item with dot indicator and icon scale.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.18 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    child: Icon(
                      icon,
                      color: selected ? AppTheme.primaryColor : Colors.white38,
                      size: 26,
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Text(
                          badge!,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  color: selected ? AppTheme.primaryColor : Colors.white38,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
                child: Text(label),
              ),
              const SizedBox(height: 4),
              // Sliding indicator dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                width: selected ? 20 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
