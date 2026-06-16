import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config_provider.dart';
import '../core/constants/app_packages.dart';

class TrackedPackagesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider).requireValue;
    final saved = prefs.getStringList('tracked_packages');
    return saved ?? AppPackages.targets.keys.toList();
  }

  Future<void> addPackage(String packageName) async {
    final prefs = ref.read(sharedPreferencesProvider).requireValue;
    final current = List<String>.from(state);
    if (!current.contains(packageName)) {
      current.add(packageName);
      state = current;
      await prefs.setStringList('tracked_packages', current);
    }
  }

  Future<void> removePackage(String packageName) async {
    final prefs = ref.read(sharedPreferencesProvider).requireValue;
    final current = List<String>.from(state);
    if (current.contains(packageName)) {
      current.remove(packageName);
      state = current;
      await prefs.setStringList('tracked_packages', current);
    }
  }
}

final trackedPackagesProvider =
    NotifierProvider<TrackedPackagesNotifier, List<String>>(
  TrackedPackagesNotifier.new,
);
