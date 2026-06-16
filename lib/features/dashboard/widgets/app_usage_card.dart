import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/config_provider.dart';
import '../../../core/constants/app_packages.dart';
import '../../../core/services/usage_service.dart';
import '../../../core/services/roast_engine.dart';
import '../../settings/view_models/settings_view_model.dart';

class AppUsageCard extends ConsumerWidget {
  final AppUsageStat stat;

  const AppUsageCard({super.key, required this.stat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final app = AppPackages.getMeta(stat.packageName);
    final name = app.name;
    final emoji = app.emoji;
    final brandColor = Color(app.color);
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
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (minutes / 120).clamp(0.0, 1.0),
                    backgroundColor: theme.colorScheme.surface,
                    valueColor: AlwaysStoppedAnimation(severity.color),
                    minHeight: 5,
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
                style: theme.textTheme.titleMedium?.copyWith(
                  color: severity.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                severity.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: severity.color.withValues(alpha: 0.7),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final useCustom = ref.watch(useCustomThresholdsProvider).value ?? false;
    if (!useCustom) {
      return Card(
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

    return Card(
      child: Column(
        children: [
          cardContent,
          Divider(color: theme.colorScheme.outline, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.timer, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), size: 16),
                const SizedBox(width: 8),
                Text(
                  'Limit: $customThreshold min',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: theme.sliderTheme.copyWith(
                      activeTrackColor: theme.colorScheme.tertiary,
                      thumbColor: theme.colorScheme.tertiary,
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                    ),
                    child: Slider(
                      value: customThreshold.toDouble(),
                      min: 1,
                      max: 60,
                      divisions: 59,
                      onChanged: (val) {
                        ref.read(settingsViewModelProvider).setCustomAppThreshold(stat.packageName, val.toInt());
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
