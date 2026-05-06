import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/config_provider.dart';
import '../../core/constants/app_packages.dart';

// ---------------------------------------------------------------------------
// Package info provider — loaded once, cached
// ---------------------------------------------------------------------------

final _packageInfoProvider = FutureProvider<PackageInfo>(
  (_) => PackageInfo.fromPlatform(),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thresholdAsync = ref.watch(thresholdMinutesProvider);
    final threshold = thresholdAsync.value ?? 10;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Threshold Setting
          _SettingsSection(
            title: '⏱️ Time Threshold',
            subtitle: 'How long before RoastGuard roasts you',
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$threshold',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'min',
                      style: TextStyle(color: Colors.white54, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                thresholdAsync.isLoading
                    ? const LinearProgressIndicator(color: Color(0xFFFF4444))
                    : SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFFFF4444),
                          inactiveTrackColor: Colors.grey[800],
                          thumbColor: const Color(0xFFFF4444),
                          overlayColor: const Color(
                            0xFFFF4444,
                          ).withValues(alpha: 0.2),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: threshold.toDouble(),
                          min: 1,
                          max: 120,
                          divisions: 119,
                          onChanged: (v) {
                            ref
                                .read(thresholdMinutesProvider.notifier)
                                .setThreshold(v.round());
                          },
                        ),
                      ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '1 min',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                    Text(
                      '2 hours',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tracked Apps
          _SettingsSection(
            title: '📱 Tracked Apps',
            subtitle: 'Apps being monitored for doomscrolling',
            child: Column(
              children: AppPackages.targets.entries.map((entry) {
                final app = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(app.color).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            app.emoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        app.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green[700],
                        size: 20,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // About — dynamic version via package_info_plus
          _AboutSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// About section with dynamic version
// ---------------------------------------------------------------------------

class _AboutSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfoAsync = ref.watch(_packageInfoProvider);

    final versionStr = packageInfoAsync.when(
      data: (info) => 'v${info.version}+${info.buildNumber}',
      loading: () => 'v—',
      error: (e, _) => 'v1.0.2',
    );

    return _SettingsSection(
      title: '🔥 About RoastGuard',
      subtitle: '$versionStr — The app that roasts you for doomscrolling',
      child: Text(
        'RoastGuard monitors your screen time on social media apps and delivers '
        'brutally honest AI-generated roasts when you exceed your time limit. '
        "It's the productivity app you didn't ask for, but desperately need.",
        style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.5),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable section card
// ---------------------------------------------------------------------------

class _SettingsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[900]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
