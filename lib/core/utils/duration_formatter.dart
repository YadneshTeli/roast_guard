/// Utility to format durations for display.
class DurationFormatter {
  DurationFormatter._();

  static String format(Duration d) {
    if (d.inHours >= 1) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes >= 1) {
      return '${d.inMinutes}m';
    }
    return '${d.inSeconds}s';
  }

  static String formatVerbose(Duration d) {
    if (d.inHours >= 1) {
      final mins = d.inMinutes.remainder(60);
      return '${d.inHours} hour${d.inHours > 1 ? 's' : ''}${mins > 0 ? ' $mins min${mins > 1 ? 's' : ''}' : ''}';
    }
    if (d.inMinutes >= 1) {
      return '${d.inMinutes} minute${d.inMinutes > 1 ? 's' : ''}';
    }
    return '${d.inSeconds} second${d.inSeconds > 1 ? 's' : ''}';
  }
}
