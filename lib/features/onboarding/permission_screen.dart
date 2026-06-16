import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'view_models/permission_view_model.dart';

class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Small delay: Android may not have fully committed the grant by the time
      // this callback fires (e.g. user grants and switches back very quickly).
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          ref.read(permissionViewModelProvider.notifier).checkPermissions();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final permissionState = ref.watch(permissionViewModelProvider);

    return Scaffold(
      body: SafeArea(
        child: permissionState.isLoading
            ? Center(
                child: CircularProgressIndicator(color: theme.colorScheme.primary),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),
                    // Animated fire emoji
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) =>
                          Transform.scale(scale: value, child: child),
                      child: const Text('🔥', style: TextStyle(fontSize: 72)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Doom Roast',
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We need permissions to roast you properly.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 48),
                    _PermissionTile(
                      icon: '📊',
                      title: 'Usage Access',
                      subtitle: "So we know how long you've been doomscrolling",
                      granted: permissionState.hasUsage,
                      onTap: () async {
                        await ref
                            .read(permissionViewModelProvider.notifier)
                            .requestUsagePermission();
                      },
                    ),
                    const SizedBox(height: 16),
                    _PermissionTile(
                      icon: '🪟',
                      title: 'Display Over Apps',
                      subtitle: 'So we can interrupt your scrolling with shame',
                      granted: permissionState.hasOverlay,
                      onTap: () async {
                        await ref
                            .read(permissionViewModelProvider.notifier)
                            .requestOverlayPermission();
                      },
                    ),
                    const SizedBox(height: 16),
                    _PermissionTile(
                      icon: '🔋',
                      title: 'Background Activity',
                      subtitle: 'Keep roasts coming even when the app is closed',
                      granted: permissionState.hasBattery,
                      onTap: () async {
                        await ref
                            .read(permissionViewModelProvider.notifier)
                            .requestBatteryBypass();
                      },
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: permissionState.allGranted ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 400),
                      child: AnimatedSlide(
                        offset: permissionState.allGranted
                            ? Offset.zero
                            : const Offset(0, 0.3),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: permissionState.allGranted
                                ? () async {
                                    await ref
                                        .read(permissionViewModelProvider.notifier)
                                        .completeOnboarding();
                                    if (context.mounted) {
                                      context.go('/dashboard');
                                    }
                                  }
                                : null,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              elevation: 4,
                              shadowColor: theme.colorScheme.primary.withValues(alpha: 0.3),
                            ),
                            child: const Text(
                              '🔥 Start Roasting Me',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PermissionTile extends StatefulWidget {
  final String icon, title, subtitle;
  final bool granted;
  final VoidCallback onTap;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onTap,
  });

  @override
  State<_PermissionTile> createState() => _PermissionTileState();
}

class _PermissionTileState extends State<_PermissionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: (_) {
        if (!widget.granted) _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        if (!widget.granted) widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child!),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.granted
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.granted
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: widget.granted ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: widget.granted
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: widget.granted
                            ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: widget.granted
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: const ValueKey('check'),
                        color: theme.colorScheme.primary,
                        size: 24,
                      )
                    : Icon(
                        Icons.arrow_forward_ios_rounded,
                        key: const ValueKey('arrow'),
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        size: 18,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
