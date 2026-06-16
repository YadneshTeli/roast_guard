import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/config_provider.dart';
import '../../providers/usage_provider.dart';
import '../../providers/streak_provider.dart';
import '../../core/constants/app_packages.dart';
import '../../core/services/roast_engine.dart';
import '../../core/services/groq_service.dart';
import '../../core/services/usage_service.dart';
import 'widgets/app_usage_card.dart';
import 'widgets/roast_intensity_slider.dart';
import 'widgets/threshold_slider.dart';
import 'view_models/dashboard_view_model.dart';

// ---------------------------------------------------------------------------
// GROQ roast provider — cached per (packageName, totalMinutes) pair
// ---------------------------------------------------------------------------

final _groqRoastProvider = FutureProvider.autoDispose
    .family<
      String,
      ({String packageName, int totalMinutes, RoastIntensity intensity})
    >(
      (ref, args) => GroqService.getRoast(
        args.packageName,
        Duration(minutes: args.totalMinutes),
        args.intensity,
      ),
    );

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

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
    final theme = Theme.of(context);
    final vm = ref.read(dashboardViewModelProvider);
    final usageAsync = ref.watch(usageStatsProvider);

    return Scaffold(
      body: SafeArea(
        child: usageAsync.when(
          loading: () => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Calculating your shame...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
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
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => vm.refreshUsage(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (stats) {
            final filtered = stats.toList()
                  ..sort((a, b) => b.totalTime.compareTo(a.totalTime));

            final totalMs = filtered.fold<int>(
              0,
              (sum, s) => sum + s.totalTime.inMilliseconds,
            );
            final totalDuration = Duration(milliseconds: totalMs);

            return RefreshIndicator(
              color: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              onRefresh: () async => vm.refreshUsage(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    floating: true,
                    scrolledUnderElevation: 0,
                    leading: IconButton(
                      icon: Icon(
                        Icons.settings_rounded,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      onPressed: () => context.push('/settings'),
                    ),
                    title: Text(
                      '🔥 Doom Roast',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    actions: [
                      const _StreakBadge(),
                      Consumer(
                        builder: (context, ref, child) {
                          final currentMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
                          IconData iconData;
                          String tooltip;
                          switch (currentMode) {
                            case ThemeMode.system:
                              iconData = Icons.brightness_auto_rounded;
                              tooltip = 'Theme: System';
                              break;
                            case ThemeMode.light:
                              iconData = Icons.light_mode_rounded;
                              tooltip = 'Theme: Light';
                              break;
                            case ThemeMode.dark:
                              iconData = Icons.dark_mode_rounded;
                              tooltip = 'Theme: Dark';
                              break;
                          }
                          return IconButton(
                            icon: Icon(iconData),
                            tooltip: tooltip,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            onPressed: () {
                              final nextMode = currentMode == ThemeMode.system
                                  ? ThemeMode.light
                                  : currentMode == ThemeMode.light
                                      ? ThemeMode.dark
                                      : ThemeMode.system;
                              ref.read(themeModeProvider.notifier).setThemeMode(nextMode);
                            },
                          );
                        },
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
                            Text(
                              "Today's Damage",
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${filtered.length} apps',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => context.push('/weekly_report'),
                              icon: const Icon(Icons.analytics_rounded, size: 16),
                              label: const Text('Weekly'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (filtered.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.colorScheme.outline),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  '🎉',
                                  style: TextStyle(fontSize: 48),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No doom-scrolling detected!',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Either you're a saint or the tracking just started.",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                        const SizedBox(height: 12),
                        const _CustomThresholdsToggle(),
                        const SizedBox(height: 20),
                        Consumer(
                          builder: (context, ref, child) {
                            final useCustom =
                                ref.watch(useCustomThresholdsProvider).value ??
                                false;
                            if (useCustom) return const SizedBox.shrink();
                            return const Column(
                              children: [
                                ThresholdSlider(),
                                SizedBox(height: 20),
                              ],
                            );
                          },
                        ),
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

// ---------------------------------------------------------------------------
// Shame summary
// ---------------------------------------------------------------------------

class _ShameSummary extends StatelessWidget {
  final Duration totalDuration;
  final int appCount;
  const _ShameSummary({required this.totalDuration, required this.appCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Today you wasted',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$appCount apps tracked',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              RoastEngine.formatDuration(totalDuration),
              style: theme.textTheme.displayLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w900,
                letterSpacing: -2,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'on apps that bring you no joy or income.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick roast card — GROQ-powered
// ---------------------------------------------------------------------------

class _QuickRoastCard extends ConsumerWidget {
  final String packageName;
  final Duration duration;
  const _QuickRoastCard({required this.packageName, required this.duration});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final intensityAsync = ref.watch(roastIntensityProvider);
    final intensity = intensityAsync.value ?? RoastIntensity.medium;

    final roastAsync = ref.watch(
      _groqRoastProvider((
        packageName: packageName,
        totalMinutes: duration.inMinutes.clamp(1, 9999),
        intensity: intensity,
      )),
    );
    final app = AppPackages.getMeta(packageName);

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('💬', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  'AI ROAST OF THE MOMENT',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(app.emoji, style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            roastAsync.when(
              loading: () => const _RoastShimmer(),
              error: (e, _) => Text(
                RoastEngine.getRoast(packageName, duration),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              data: (roast) => Text(
                roast,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoastShimmer extends StatefulWidget {
  const _RoastShimmer();

  @override
  State<_RoastShimmer> createState() => _RoastShimmerState();
}

class _RoastShimmerState extends State<_RoastShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 0.7).animate(_anim),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 14,
            width: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tracking toggle
// ---------------------------------------------------------------------------

class _TrackingToggle extends ConsumerWidget {
  const _TrackingToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vm = ref.read(dashboardViewModelProvider);
    final trackingAsync = ref.watch(trackingEnabledProvider);
    final isTracking = trackingAsync.value ?? true;

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isTracking
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isTracking
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: isTracking
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Monitoring',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isTracking
                        ? 'Doom Roast is watching'
                        : 'Paused for productivity',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isTracking
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            trackingAsync.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFF3333),
                    ),
                  )
                : Switch(
                    value: isTracking,
                    onChanged: (val) {
                      vm.toggleTracking(val);
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom thresholds toggle
// ---------------------------------------------------------------------------

class _CustomThresholdsToggle extends ConsumerWidget {
  const _CustomThresholdsToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vm = ref.read(dashboardViewModelProvider);
    final customAsync = ref.watch(useCustomThresholdsProvider);
    final useCustom = customAsync.value ?? false;

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.tune, color: theme.colorScheme.tertiary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom App Limits',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    useCustom
                        ? 'Specific limits per app'
                        : 'Global threshold active',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            customAsync.isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.tertiary,
                    ),
                  )
                : Switch(
                    value: useCustom,
                    onChanged: (val) {
                      vm.toggleCustomThresholds(val);
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Streak badge
// ---------------------------------------------------------------------------

class _StreakBadge extends ConsumerWidget {
  const _StreakBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final streakAsync = ref.watch(streakProvider);
    final streak = streakAsync.value ?? 0;

    if (streak == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: TextStyle(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
