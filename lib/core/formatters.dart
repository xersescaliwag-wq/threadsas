// lib/core/formatters.dart

/// Short relative time such as 5m, 3h or 2d. Older posts show a date.
String timeAgo(DateTime time, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(time);
  if (difference.inSeconds < 60) return 'now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m';
  if (difference.inHours < 24) return '${difference.inHours}h';
  if (difference.inDays < 7) return '${difference.inDays}d';
  return '${time.day}/${time.month}/${time.year}';
}

/// Readable relative  time for post and reply metadata, such as "23 mins" or
/// "1 hr".
String timeAgoLong(DateTime time, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(time);
  if (difference.inSeconds < 60) return 'now';
  if (difference.inMinutes < 60) {
    final value = difference.inMinutes;
    return '$value ${value == 1 ? 'min' : 'mins'}';
  }
  if (difference.inHours < 24) {
    final value = difference.inHours;
    return '$value ${value == 1 ? 'hr' : 'hrs'}';
  }
  if (difference.inDays < 7) {
    final value = difference.inDays;
    return '$value ${value == 1 ? 'day' : 'days'}';
  }
  return '${time.day}/${time.month}/${time.year}';
}

/// Compact counts such as 950, 1.2K or 3.4M.
String compactCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

final RegExp _usernamePattern = RegExp(r'^[a-z0-9_.]{3,30}$');

/// Returns an error message, or null when the username is valid.
String? validateUsername(String value) {
  final username = value.trim().toLowerCase();
  if (!_usernamePattern.hasMatch(username)) {
    return 'Use 3 to 30 letters, numbers, periods or underscores.';
  }
  return null;
}
