// screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/app_theme.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';

// Conditional import for web localStorage
import 'onboarding_stub.dart' if (dart.library.js_interop) 'onboarding_web.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool _locationGranted = false;
  bool _notificationsGranted = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<_OnboardingStep> _steps = [
    _OnboardingStep(
      icon: Icons.local_hospital_rounded,
      iconColor: AppTheme.primaryColor,
      title: 'مرحباً بك 👋',
      description:
          'أهلاً بك في نظام الحضور والانصراف\n\nهذا التطبيق يساعدك في تسجيل حضورك وانصرافك بسهولة، ومتابعة سجلاتك اليومية.',
      gradient: AppTheme.primaryGradient,
    ),
    _OnboardingStep(
      icon: Icons.fingerprint_rounded,
      iconColor: Colors.green,
      title: 'تسجيل الحضور ✅',
      description:
          '١. افتح تاب "تسجيل الحضور" من القائمة السفلية\n\n٢. اكتب اسمك في الخانة المخصصة\n\n٣. اضغط على زر "تسجيل الحضور"\n\n٤. لو وصلت متأخر، هيطلب منك تكتب عذر',
      gradient: const LinearGradient(
        colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _OnboardingStep(
      icon: Icons.exit_to_app_rounded,
      iconColor: Colors.blue,
      title: 'تسجيل الانصراف 🚪',
      description:
          '١. افتح تاب "انصراف" من القائمة السفلية\n\n٢. اكتب اسمك كما سجلته في الحضور\n\n٣. اضغط زر "تسجيل انصراف"\n\n✅ هيتم تسجيل وقت مغادرتك تلقائياً',
      gradient: const LinearGradient(
        colors: [Color(0xFF2196F3), Color(0xFF0D47A1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _OnboardingStep(
      icon: Icons.location_on_rounded,
      iconColor: Colors.orange,
      title: 'صلاحية الموقع 📍',
      description:
          'نحتاج إذنك لاستخدام الموقع حتى نتأكد أنك في نطاق العمل عند تسجيل الحضور.\n\nاضغط الزر بالأسفل للسماح بالوصول للموقع.',
      gradient: const LinearGradient(
        colors: [Color(0xFFFF9800), Color(0xFFE65100)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      isLocationStep: true,
    ),
    _OnboardingStep(
      icon: Icons.notifications_active_rounded,
      iconColor: Colors.purple,
      title: 'الإشعارات 🔔',
      description:
          'فعّل الإشعارات حتى تصلك تنبيهات مهمة عن الحضور والانصراف.\n\nاضغط الزر بالأسفل للسماح بالإشعارات.',
      gradient: const LinearGradient(
        colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      isNotificationStep: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() {
    markOnboardingDone();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        setState(() => _locationGranted = true);
      }
    } catch (_) {
      // On web, permission is usually granted here
      setState(() => _locationGranted = true);
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      await NotificationService().init();
      setState(() => _notificationsGranted = true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: _completeOnboarding,
                    child: const Text(
                      'تخطي',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ),
                ),
              ),

              // PageView
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _steps.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (ctx, i) => _buildPage(_steps[i]),
                ),
              ),

              // Page indicators + Next button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    // Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _steps.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == i ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == i
                                ? AppTheme.primaryColor
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action button
                    _buildActionButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingStep step) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          // Icon container with glow
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: step.gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: step.iconColor.withAlpha(80),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(step.icon, color: Colors.white, size: 56),
          ),
          const SizedBox(height: 36),

          // Title
          Text(
            step.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Description card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: step.iconColor.withAlpha(40)),
            ),
            child: Text(
              step.description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.7,
              ),
              textAlign: TextAlign.right,
            ),
          ),

          // Permission status badges
          if (step.isLocationStep && _locationGranted) ...[
            const SizedBox(height: 16),
            _permissionBadge('✅ تم السماح بالموقع', Colors.green),
          ],
          if (step.isNotificationStep && _notificationsGranted) ...[
            const SizedBox(height: 16),
            _permissionBadge('✅ تم تفعيل الإشعارات', Colors.green),
          ],

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _permissionBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: color, size: 20),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final step = _steps[_currentPage];
    final isLast = _currentPage == _steps.length - 1;

    // Location step: show permission button
    if (step.isLocationStep && !_locationGranted) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _requestLocationPermission,
              icon:
                  const Icon(Icons.location_on_rounded, color: Colors.white),
              label: const Text('السماح بالموقع',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _nextPage,
            child: const Text('تخطي هذه الخطوة',
                style: TextStyle(color: Colors.white38)),
          ),
        ],
      );
    }

    // Notification step: show permission button
    if (step.isNotificationStep && !_notificationsGranted) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _requestNotificationPermission,
              icon: const Icon(Icons.notifications_active_rounded,
                  color: Colors.white),
              label: const Text('تفعيل الإشعارات',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _nextPage,
            child: const Text('تخطي هذه الخطوة',
                style: TextStyle(color: Colors.white38)),
          ),
        ],
      );
    }

    // After granting a permission, show "Next" instead
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _nextPage,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
        ),
        child: Text(
          isLast ? 'ابدأ الآن 🚀' : 'التالي ←',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _OnboardingStep {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final LinearGradient gradient;
  final bool isLocationStep;
  final bool isNotificationStep;

  const _OnboardingStep({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.gradient,
    this.isLocationStep = false,
    this.isNotificationStep = false,
  });
}
