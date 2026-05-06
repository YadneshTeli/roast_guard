import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/config_provider.dart';

class ThresholdSlider extends ConsumerWidget {
  const ThresholdSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thresholdAsync = ref.watch(thresholdMinutesProvider);
    final threshold = thresholdAsync.value ?? 10;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[900]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Spam Threshold',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                thresholdAsync.isLoading ? '…' : '$threshold mins',
                style: const TextStyle(
                  color: Color(0xFFFF8800),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Time allowed before the roasting begins',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFFFF4444),
              inactiveTrackColor: Colors.grey[800],
              thumbColor: const Color(0xFFFF8800),
              overlayColor: const Color(0xFFFF4444).withValues(alpha: 0.2),
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            ),
            child: Slider(
              value: threshold.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              onChanged: (value) {
                ref
                    .read(thresholdMinutesProvider.notifier)
                    .setThreshold(value.toInt());
              },
            ),
          ),
        ],
      ),
    );
  }
}
