import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/attendance_provider.dart';
import 'screens/home_screen.dart';
import 'utils/app_theme.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://ukokmqxplozolomupujv.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVrb2ttcXhwbG96b2xvbXVwdWp2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1MDg4ODMsImV4cCI6MjA4NzA4NDg4M30.XQ3WgYJIYlM0R0BWx2rC1CeYooC0TLHbKkdH25YD9ks',
  );

  await initializeDateFormatting('ar', null);
  // Initialize local notifications
  await NotificationService().init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const RadiologyAttendanceApp());
}

class RadiologyAttendanceApp extends StatelessWidget {
  const RadiologyAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AttendanceProvider(),
      child: MaterialApp(
        title: 'مركز الأشعة - حضور وانصراف',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        locale: const Locale('ar'),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
