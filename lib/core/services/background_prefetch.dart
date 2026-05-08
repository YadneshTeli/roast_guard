import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../providers/config_provider.dart';
import 'groq_service.dart';

/// Unique task name used by both the registration and the callback dispatcher.
const kPrefetchTaskName = 'roastPrefetchTask';

/// Top-level callback entry point for the WorkManager background isolate.
/// Android spins up a minimal Flutter engine and calls this function;
/// it must be a top-level or static function (no closures).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != kPrefetchTaskName) return true;

    try {
      // Load .env so GroqService can read GROQ_API
      await dotenv.load(fileName: '.env');

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Ensure fresh data cross-process

      // Read the pending package name set by ForegroundMonitorService
      final packageName = prefs.getString('roast_prefetch_pending');
      if (packageName == null || packageName.isEmpty) return true;

      // Clear immediately to prevent duplicate fetches
      await prefs.remove('roast_prefetch_pending');

      final intensityIndex = prefs.getInt('roast_intensity') ?? 1;
      final intensity = RoastIntensity.values[intensityIndex.clamp(0, 2)];

      await GroqService.prefetchSingleRoast(packageName, intensity);
    } catch (_) {
      // Best-effort — overlay will use static fallback if this fails
    }

    return true; // Signal success to WorkManager
  });
}
