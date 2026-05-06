import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/config_provider.dart';
import '../../../core/constants/app_packages.dart';
import '../../../core/services/usage_service.dart';
import '../../../core/services/roast_engine.dart';

class AppUsageCard extends ConsumerWidget {
  final AppUsageStat stat;

  const AppUsageCard({super.key, required this.stat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = AppPackages.targets[stat.packageName];
    final name = app?.name ?? stat.packageName;
    final emoji = app?.emoji ?? '📱';
    final brandColor = Color(app?.color ?? 0xFFFF4444);
    final timeStr = RoastEngine.formatDuration(stat.totalTime);

    // Determine severity
    final minutes = stat.totalTime.inMinutes;
    final severity = minutes >= 60
        ? _Severity.critical
        : minutes >= 30
        ? _Severity.warning
        : minutes >= 10
        ? _Severity.moderate
        : _Severity.low;

    final cardContent = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // App Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),

          // App Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (minutes / 120).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[900],
                    valueColor: AlwaysStoppedAnimation(severity.color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeStr,
                style: TextStyle(
                  color: severity.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                severity.label,
                style: TextStyle(
                  color: severity.color.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final useCustom = ref.watch(useCustomThresholdsProvider).value ?? false;
    if (!useCustom) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: severity.color.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: cardContent,
      );
    }

    final customThresholdAsync = ref.watch(
      customThresholdProvider(stat.packageName),
    );
    final customThreshold =
        customThresholdAsync.value == -1 || customThresholdAsync.value == null
        ? ref.watch(thresholdMinutesProvider).value ?? 10
        : customThresholdAsync.value!;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: severity.color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          cardContent,
          const Divider(color: Colors.white10, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.grey, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Limit: $customThreshold min',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                      activeTrackColor: const Color(0xFF8B5CF6),
                      inactiveTrackColor: Colors.grey[800],
                      thumbColor: const Color(0xFF8B5CF6),
                    ),
                    child: Slider(
                      value: customThreshold.toDouble(),
                      min: 1,
                      max: 60,
                      divisions: 59,
                      onChanged: (val) async {
                        final prefs = await ref.read(
                          sharedPreferencesProvider.future,
                        );
                        await prefs.setInt(
                          'custom_threshold_${stat.packageName}_minutes',
                          val.toInt(),
                        );
                        ref.invalidate(
                          customThresholdProvider(stat.packageName),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Severity {
  low(Color(0xFF22C55E), 'Chill'),
  moderate(Color(0xFFEAB308), 'Hmm...'),
  warning(Color(0xFFFF8800), 'Yikes'),
  critical(Color(0xFFFF4444), 'Bruh');

  const _Severity(this.color, this.label);
  final Color color;
  final String label;
}
