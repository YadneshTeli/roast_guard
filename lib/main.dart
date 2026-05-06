import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/onboarding/permission_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/reports/weekly_report_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (.env must be listed in pubspec assets)
  await dotenv.load(fileName: '.env');

  // Initialise flutter_foreground_task notification channel
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'roastguard_monitor',
      channelName: 'RoastGuard Monitor',
      channelDescription: 'Monitoring your screen time habits',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(15000),
      autoRunOnBoot: true,
      allowWifiLock: false,
    ),
  );

  // Force dark status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  final onboarded = prefs.getBool('onboarding_complete') ?? false;

  runApp(ProviderScope(child: RoastGuardApp(skipOnboarding: onboarded)));
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

GoRouter _buildRouter(bool skipOnboarding) => GoRouter(
  initialLocation: skipOnboarding ? '/dashboard' : '/',
  routes: [
    GoRoute(path: '/', builder: (context, _) => const PermissionScreen()),
    GoRoute(
      path: '/dashboard',
      builder: (context, _) => const DashboardScreen(),
    ),
    GoRoute(path: '/settings', builder: (context, _) => const SettingsScreen()),
    GoRoute(
      path: '/weekly_report',
      builder: (context, _) => const WeeklyReportScreen(),
    ),
  ],
);

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

class RoastGuardApp extends StatelessWidget {
  final bool skipOnboarding;
  const RoastGuardApp({super.key, required this.skipOnboarding});

  @override
  Widget build(BuildContext context) {
    final router = _buildRouter(skipOnboarding);

    return WithForegroundTask(
      child: MaterialApp.router(
        title: 'Doom Roast',
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0A0A0A),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF4444),
            brightness: Brightness.dark,
            surface: const Color(0xFF0A0A0A),
          ),
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
