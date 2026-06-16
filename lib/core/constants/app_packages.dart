/// Metadata for tracked apps — package names, display names, and emojis.
class AppPackages {
  AppPackages._();

  static const Map<String, AppMeta> targets = {
    'com.instagram.android': AppMeta(
      name: 'Instagram',
      emoji: '📸',
      color: 0xFFE1306C,
    ),
    'com.twitter.android': AppMeta(
      name: 'Twitter/X',
      emoji: '🐦',
      color: 0xFF1DA1F2,
    ),
    'com.facebook.katana': AppMeta(
      name: 'Facebook',
      emoji: '👴',
      color: 0xFF1877F2,
    ),
    'com.google.android.youtube': AppMeta(
      name: 'YouTube',
      emoji: '📺',
      color: 0xFFFF0000,
    ),
    'com.zhiliaoapp.musically': AppMeta(
      name: 'TikTok',
      emoji: '🎵',
      color: 0xFF010101,
    ),
    'com.reddit.frontpage': AppMeta(
      name: 'Reddit',
      emoji: '👽',
      color: 0xFFFF5700,
    ),
    'com.snapchat.android': AppMeta(
      name: 'Snapchat',
      emoji: '👻',
      color: 0xFFFFFC00,
    ),
  };

  static AppMeta getMeta(String packageName, {String? displayName}) {
    final meta = targets[packageName];
    if (meta != null) return meta;

    final name = displayName ?? _cleanPackageName(packageName);
    // Generate a stable color based on hash of package name
    final hash = packageName.hashCode;
    final color = 0xFF000000 | (hash & 0x00FFFFFF);

    return AppMeta(
      name: name,
      emoji: '📱',
      color: color,
    );
  }

  static String _cleanPackageName(String pkg) {
    final parts = pkg.split('.');
    if (parts.isEmpty) return pkg;
    final last = parts.last;
    if (last.isEmpty) return pkg;
    if (last.length > 1) {
      return last[0].toUpperCase() + last.substring(1);
    }
    return last.toUpperCase();
  }
}

class AppMeta {
  final String name;
  final String emoji;
  final int color;

  const AppMeta({required this.name, required this.emoji, required this.color});
}
