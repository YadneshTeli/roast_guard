import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'config_provider.dart';

final streakProvider = AsyncNotifierProvider<StreakNotifier, int>(
  StreakNotifier.new,
);

class StreakNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    return _calculateStreak();
  }

  Future<int> _calculateStreak() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final formatter = DateFormat('yyyy-MM-dd');
    final today = DateTime.now();
    final todayStr = formatter.format(today);

    final lastOpenedStr = prefs.getString('last_opened_date');
    var streak = prefs.getInt('current_streak') ?? 0;

    // If already calculated today, just return current streak
    if (lastOpenedStr == todayStr) {
      return streak;
    }

    if (lastOpenedStr != null) {
      final lastOpened = formatter.parse(lastOpenedStr);
      final difference = today.difference(lastOpened).inDays;

      if (difference == 1) {
        // Opened yesterday! Did we break it?
        final lastBrokenStr = prefs.getString('last_broken_date');
        final yesterdayStr = formatter.format(
          today.subtract(const Duration(days: 1)),
        );

        if (lastBrokenStr == yesterdayStr) {
          // We broke the rules yesterday
          streak = 0;
        } else {
          // We survived yesterday!
          streak += 1;
        }
      } else if (difference > 1) {
        // Missed a day of checking in. Reset streak.
        streak = 0;
      }
    } else {
      // First time ever opening the app
      streak = 0;
    }

    // Save state
    await prefs.setString('last_opened_date', todayStr);
    await prefs.setInt('current_streak', streak);

    return streak;
  }
}
