import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'features/onboarding/permission_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/reports/weekly_report_screen.dart';
import 'core/services/groq_service.dart';
import 'core/services/background_prefetch.dart';
import 'providers/config_provider.dart';

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

  // Persist GROQ API key so native OverlayService can read it directly
  final groqKey = dotenv.env['GROQ_API'] ?? '';
  if (groqKey.isNotEmpty) {
    await prefs.setString('groq_api_key', groqKey);
  }

  // Initialise WorkManager for background roast prefetch tasks
  await Workmanager().initialize(callbackDispatcher);

  // Register a periodic background task that checks the prefetch flag
  // and fetches a fresh roast even if the user never opens the app.
  // Android enforces a 15-minute minimum interval for periodic tasks.
  await Workmanager().registerPeriodicTask(
    'periodicRoastPrefetch',
    kPrefetchTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  // Pre-fetch AI roasts per app in background — OverlayService reads from cache
  final intensityIndex = prefs.getInt('roast_intensity') ?? 1;
  final intensity = RoastIntensity.values[intensityIndex.clamp(0, 2)];
  GroqService.prefetchRoasts(intensity); // fire-and-forget

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

class RoastGuardApp extends ConsumerStatefulWidget {
  final bool skipOnboarding;
  const RoastGuardApp({super.key, required this.skipOnboarding});

  @override
  ConsumerState<RoastGuardApp> createState() => _RoastGuardAppState();
}

class _RoastGuardAppState extends ConsumerState<RoastGuardApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onResume: _onAppResumed);
  }

  /// Called every time the app returns to the foreground.
  /// Checks whether ForegroundMonitorService left a pending-prefetch flag
  /// and, if so, fetches a fresh roast for that specific package.
  Future<void> _onAppResumed() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    
    // IMPORTANT: Reload from disk because the Kotlin native service 
    // modifies this flag in the background while the Flutter app is asleep.
    await prefs.reload();
    
    final pendingPackage = prefs.getString('roast_prefetch_pending');
    if (pendingPackage == null || pendingPackage.isEmpty) return;

    // Clear the flag immediately so a repeated resume doesn't double-fetch.
    await prefs.remove('roast_prefetch_pending');

    final intensityIndex = prefs.getInt('roast_intensity') ?? 1;
    final intensity = RoastIntensity.values[intensityIndex.clamp(0, 2)];

    // Targeted fetch — only the package whose cache was just consumed
    GroqService.prefetchSingleRoast(pendingPackage, intensity);
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = _buildRouter(widget.skipOnboarding);

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
