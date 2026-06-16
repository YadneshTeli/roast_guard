import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../view_models/dashboard_view_model.dart';
import '../../../providers/config_provider.dart';

class RoastIntensitySlider extends ConsumerWidget {
  const RoastIntensitySlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vm = ref.read(dashboardViewModelProvider);
    final intensityAsync = ref.watch(roastIntensityProvider);
    final intensity = intensityAsync.value ?? RoastIntensity.medium;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  'Roast Intensity',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<RoastIntensity>(
              segments: RoastIntensity.values.map((level) {
                final labelText = level.label.split(' ').first;
                return ButtonSegment<RoastIntensity>(
                  value: level,
                  label: Text(
                    labelText,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  icon: Text(level.emoji),
                );
              }).toList(),
              selected: {intensity},
              onSelectionChanged: (Set<RoastIntensity> newSelection) {
                if (newSelection.isNotEmpty) {
                  vm.setRoastIntensity(newSelection.first);
                }
              },
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                selectedForegroundColor: theme.colorScheme.primary,
                side: BorderSide(color: theme.colorScheme.outline),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              intensity.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
