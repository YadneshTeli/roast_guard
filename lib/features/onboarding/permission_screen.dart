import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/usage_service.dart';

class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen>
    with WidgetsBindingObserver {
  final _usageService = UsageService();
  bool _hasUsage = false;
  bool _hasOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
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
      Future.delayed(const Duration(milliseconds: 300), _checkPermissions);
    }
  }

  Future<void> _checkPermissions() async {
    final usage = await _usageService.hasUsagePermission();
    final overlay = await _usageService.hasOverlayPermission();
    if (mounted) {
      setState(() {
        _hasUsage = usage;
        _hasOverlay = overlay;
      });
    }
  }

  Future<void> _requestPermissions() async {
    // Request foreground task notification permission (Android 13+)
    await FlutterForegroundTask.requestNotificationPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
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
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFF4444), Color(0xFFFF8800)],
                ).createShader(bounds),
                child: const Text(
                  'Doom Roast',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We need two permissions to roast you properly.',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 48),
              _PermissionTile(
                icon: '📊',
                title: 'Usage Access',
                subtitle: "So we know how long you've been doomscrolling",
                granted: _hasUsage,
                onTap: () async {
                  await _usageService.requestUsagePermission();
                },
              ),
              const SizedBox(height: 16),
              _PermissionTile(
                icon: '🪟',
                title: 'Display Over Apps',
                subtitle: 'So we can interrupt your scrolling with shame',
                granted: _hasOverlay,
                onTap: () async {
                  await _usageService.requestOverlayPermission();
                },
              ),
              const Spacer(),
              AnimatedOpacity(
                opacity: (_hasUsage && _hasOverlay) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: AnimatedSlide(
                  offset: (_hasUsage && _hasOverlay)
                      ? Offset.zero
                      : const Offset(0, 0.3),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_hasUsage && _hasOverlay)
                          ? () async {
                              // Request notification permission for foreground task (Android 13+)
                              await _requestPermissions();
                              await _usageService.startMonitorService();
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool('onboarding_complete', true);
                              if (context.mounted) {
                                context.go('/dashboard');
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 8,
                        shadowColor: const Color(
                          0xFFFF4444,
                        ).withValues(alpha: 0.4),
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
                ? const Color(0xFF0D2818)
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.granted
                  ? const Color(0xFF22C55E)
                  : Colors.grey[800]!,
              width: 1.5,
            ),
            boxShadow: widget.granted
                ? [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: widget.granted
                    ? const Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey('check'),
                        color: Color(0xFF22C55E),
                        size: 24,
                      )
                    : const Icon(
                        Icons.arrow_forward_ios_rounded,
                        key: ValueKey('arrow'),
                        color: Colors.grey,
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
