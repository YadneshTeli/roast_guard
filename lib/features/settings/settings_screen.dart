import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'view_models/settings_view_model.dart';
import '../../providers/config_provider.dart';
import '../../providers/tracked_packages_provider.dart';
import '../../providers/usage_provider.dart';
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
    final theme = Theme.of(context);
    final vm = ref.read(settingsViewModelProvider);
    final thresholdAsync = ref.watch(thresholdMinutesProvider);
    final threshold = thresholdAsync.value ?? 10;
    final trackedPackages = ref.watch(trackedPackagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'min',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                thresholdAsync.isLoading
                    ? LinearProgressIndicator(color: theme.colorScheme.primary)
                    : Slider(
                        value: threshold.toDouble(),
                        min: 1,
                        max: 120,
                        divisions: 119,
                        onChanged: (v) {
                          vm.setThreshold(v.round());
                        },
                      ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '1 min',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    Text(
                      '2 hours',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (trackedPackages.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No apps tracked. Tap Manage to add some!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  ...trackedPackages.map((packageName) {
                    final app = AppPackages.getMeta(packageName);
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
                          Expanded(
                            child: Text(
                              app.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.remove_circle_outline_rounded,
                              color: theme.colorScheme.error,
                              size: 20,
                            ),
                            onPressed: () {
                              ref.read(trackedPackagesProvider.notifier).removePackage(packageName);
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showAppSelectionSheet(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Manage Apps'),
                  ),
                ),
              ],
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

  void _showAppSelectionSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return const _AppSelectionSheetContent();
      },
    );
  }
}

// ---------------------------------------------------------------------------
// App Selection Sheet Content
// ---------------------------------------------------------------------------

class _AppSelectionSheetContent extends ConsumerStatefulWidget {
  const _AppSelectionSheetContent();

  @override
  ConsumerState<_AppSelectionSheetContent> createState() =>
      __AppSelectionSheetContentState();
}

class __AppSelectionSheetContentState
    extends ConsumerState<_AppSelectionSheetContent> {
  String _searchQuery = '';
  List<Map<String, String>> _installedApps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    try {
      final apps = await ref.read(usageServiceProvider).getInstalledApps();
      if (mounted) {
        setState(() {
          _installedApps = apps;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error loading installed apps: $e\n$stack');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tracked = ref.watch(trackedPackagesProvider);

    final filtered = _installedApps.where((app) {
      final name = app['name'] ?? '';
      final pkg = app['packageName'] ?? '';
      final query = _searchQuery.toLowerCase();
      return name.toLowerCase().contains(query) ||
          pkg.toLowerCase().contains(query);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Track Apps',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search apps...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No apps found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final app = filtered[index];
                          final pkg = app['packageName'] ?? '';
                          final name = app['name'] ?? '';
                          final isTracked = tracked.contains(pkg);
                          final meta = AppPackages.getMeta(pkg, displayName: name);

                          return CheckboxListTile(
                            value: isTracked,
                            activeColor: theme.colorScheme.primary,
                            title: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              pkg,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            secondary: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Color(meta.color).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  meta.emoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                            onChanged: (checked) {
                              if (checked == true) {
                                ref.read(trackedPackagesProvider.notifier).addPackage(pkg);
                              } else {
                                ref.read(trackedPackagesProvider.notifier).removePackage(pkg);
                              }
                            },
                          );
                        },
                      ),
          ),
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
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
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
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
