import 'dart:math';

/// Engine that generates roast messages based on app package name and usage time.
class RoastEngine {
  RoastEngine._();

  static final _random = Random();

  static const _roasts = <String, List<String>>{
    'com.instagram.android': [
      "You've been on Instagram for {time}. The algorithm is winning. You are losing.",
      "Congrats, {time} watching people who are actually doing things.",
      "Instagram called. Even they think you need to touch grass.",
      "{time} of reels. Zero reels of your own life recorded.",
      "You've scrolled {time} worth of content. Your dreams are still loading.",
    ],
    'com.twitter.android': [
      "{time} on Twitter. You haven't changed a single mind. Log off.",
      "Breaking: Local person wastes {time} arguing with strangers online.",
      "{time} of hot takes. None of them were yours.",
      "You spent {time} on Twitter. The timeline is fine. Your productivity is not.",
    ],
    'com.facebook.katana': [
      "{time} on Facebook. Are you okay? Do you need help?",
      "You've been on Facebook for {time}. Your parents are literally the target audience.",
      "{time} of Facebook. You are becoming your parents. This is not a compliment.",
    ],
    'com.google.android.youtube': [
      "{time} on YouTube. You started with one video. Classic.",
      "The recommended algorithm has claimed another {time} of your life.",
      "{time} of YouTube. You could have built something. Instead you watched someone else build.",
      "You've watched {time} of content. Your own channel still has 0 videos.",
    ],
    'com.zhiliaoapp.musically': [
      "{time} on TikTok. Your attention span is now 3 seconds. Congratulations.",
      "You've lost {time} to 15-second videos. Do the math. That's a lot of videos.",
    ],
    'com.reddit.frontpage': [
      "{time} on Reddit. You've learned a lot about things that don't matter.",
      "You spent {time} on Reddit. AMA: How does it feel to waste your potential?",
    ],
    'com.snapchat.android': [
      "{time} on Snapchat. Those streaks won't help your resume.",
      "You spent {time} sending disappearing messages. Much like your productivity.",
    ],
  };

  static const _genericRoasts = [
    "Put your phone down. Whatever you're looking for isn't in there.",
    "{time} of your finite life. Gone.",
    "Your future self is cringing at you right now.",
    "Get a job. Or at least pretend to.",
    "{time} scrolled. Zero progress made. You're built different (not in a good way).",
  ];

  /// Get a random roast for a specific app and usage duration.
  static String getRoast(String packageName, Duration time) {
    final timeStr = formatDuration(time);
    final list = _roasts[packageName] ?? _genericRoasts;
    final roast = list[_random.nextInt(list.length)];
    return roast.replaceAll('{time}', timeStr);
  }

  /// Format a Duration into a human-readable string (e.g., "1h 23m" or "45m").
  static String formatDuration(Duration d) {
    if (d.inHours >= 1) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes >= 1) {
      return '${d.inMinutes}m';
    }
    return '${d.inSeconds}s';
  }
}
