import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../settings/view_models/settings_view_model.dart';
import '../../../providers/config_provider.dart';

class ThresholdSlider extends ConsumerWidget {
  const ThresholdSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vm = ref.read(settingsViewModelProvider);
    final thresholdAsync = ref.watch(thresholdMinutesProvider);
    final threshold = thresholdAsync.value ?? 10;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spam Threshold',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  thresholdAsync.isLoading ? '…' : '$threshold mins',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Time allowed before the roasting begins',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Slider(
              value: threshold.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              onChanged: (value) {
                vm.setThreshold(value.toInt());
              },
            ),
          ],
        ),
      ),
    );
  }
}
