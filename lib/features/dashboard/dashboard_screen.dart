import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/usage_provider.dart';
import '../../providers/config_provider.dart';
import '../../core/constants/app_packages.dart';
import '../../core/services/roast_engine.dart';
import '../../core/services/usage_service.dart';
import 'widgets/app_usage_card.dart';
import 'widgets/roast_intensity_slider.dart';
import 'widgets/threshold_slider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _usageService = UsageService();

  @override
  void initState() {
    super.initState();
    // Always ensure the monitoring service is running if tracking is enabled
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('tracking_enabled') ?? true;
      if (enabled) {
        _usageService.startMonitorService();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final usageAsync = ref.watch(usageStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: usageAsync.when(
          loading: () => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Color(0xFFFF4444),
                  strokeWidth: 3,
                ),
                SizedBox(height: 16),
                Text(
                  'Calculating your shame...',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('😵', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text(
                    'Error: $e',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(usageStatsProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4444),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (stats) {
            final filtered =
                stats
                    .where(
                      (s) => AppPackages.targets.containsKey(s.packageName),
                    )
                    .toList()
                  ..sort((a, b) => b.totalTime.compareTo(a.totalTime));

            final totalMs = filtered.fold<int>(
              0,
              (sum, s) => sum + s.totalTime.inMilliseconds,
            );
            final totalDuration = Duration(milliseconds: totalMs);

            return RefreshIndicator(
              color: const Color(0xFFFF4444),
              backgroundColor: const Color(0xFF1A1A1A),
              onRefresh: () async => ref.invalidate(usageStatsProvider),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    floating: true,
                    title: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFFF4444), Color(0xFFFF8800)],
                      ).createShader(bounds),
                      child: const Text(
                        '🔥 Doom Roast',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(
                          Icons.settings_rounded,
                          color: Colors.white70,
                        ),
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/settings'),
                      ),
                    ],
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _ShameSummary(
                          totalDuration: totalDuration,
                          appCount: filtered.length,
                        ),
                        const SizedBox(height: 28),
                        if (filtered.isNotEmpty) ...[
                          _QuickRoastCard(
                            packageName: filtered.first.packageName,
                            duration: filtered.first.totalTime,
                          ),
                          const SizedBox(height: 28),
                        ],
                        Row(
                          children: [
                            const Text(
                              "Today's Damage",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFFF4444,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${filtered.length} apps',
                                style: const TextStyle(
                                  color: Color(0xFFFF4444),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (filtered.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[900]!),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  '🎉',
                                  style: TextStyle(fontSize: 48),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No doom-scrolling detected!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Either you're a saint or the tracking just started.",
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          ...filtered.map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppUsageCard(stat: s),
                            ),
                          ),
                        const SizedBox(height: 12),
                        const _TrackingToggle(),
                        const SizedBox(height: 20),
                        const ThresholdSlider(),
                        const SizedBox(height: 20),
                        const RoastIntensitySlider(),
                        const SizedBox(height: 32),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShameSummary extends StatelessWidget {
  final Duration totalDuration;
  final int appCount;
  const _ShameSummary({required this.totalDuration, required this.appCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B0000), Color(0xFF2D0000), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4444).withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Today you wasted',
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$appCount apps tracked',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            RoastEngine.formatDuration(totalDuration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 52,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'on apps that bring you no joy or income.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickRoastCard extends StatelessWidget {
  final String packageName;
  final Duration duration;
  const _QuickRoastCard({required this.packageName, required this.duration});

  @override
  Widget build(BuildContext context) {
    final roast = RoastEngine.getRoast(packageName, duration);
    final app = AppPackages.targets[packageName];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF8800).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💬', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'Roast of the Moment',
                style: TextStyle(
                  color: Colors.orange[300],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              if (app != null) ...[
                const Spacer(),
                Text(app.emoji, style: const TextStyle(fontSize: 16)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            roast,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingToggle extends ConsumerWidget {
  const _TrackingToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTracking = ref.watch(trackingEnabledProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTracking ? const Color(0xFF22C55E).withValues(alpha: 0.3) : Colors.grey[800]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isTracking ? const Color(0xFF0D2818) : Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isTracking ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              color: isTracking ? const Color(0xFF22C55E) : Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active Monitoring',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isTracking ? 'Doom Roast is watching' : 'Paused for productivity',
                  style: TextStyle(
                    color: isTracking ? const Color(0xFF22C55E) : Colors.grey[500],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isTracking,
            activeTrackColor: const Color(0xFF22C55E).withValues(alpha: 0.5),
            activeThumbColor: const Color(0xFF22C55E),
            onChanged: (val) {
              ref.read(trackingEnabledProvider.notifier).toggleTracking(val);
            },
          ),
        ],
      ),
    );
  }
}
