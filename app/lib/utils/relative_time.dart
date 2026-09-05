/// "09:14 AM" for today, "Yesterday", "3d ago" otherwise -- matches the
/// mixed absolute/relative timestamps in the 05_DESIGN.md §2.1/§2.3 mock
/// ("09:14 AM · MG Road" for today's events, dated ones further back).
String formatEventTimestamp(DateTime timestamp, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(timestamp);
  final sameDay = timestamp.year == n.year && timestamp.month == n.month && timestamp.day == n.day;
  if (sameDay) return _formatClock(timestamp);

  final yesterday = n.subtract(const Duration(days: 1));
  final wasYesterday = timestamp.year == yesterday.year && timestamp.month == yesterday.month && timestamp.day == yesterday.day;
  if (wasYesterday) return 'Yesterday';

  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
}

String _formatClock(DateTime t) {
  final hour24 = t.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  final period = hour24 < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

/// "4m ago" / "2h ago" -- device-health-style recency (05_DESIGN.md §2.4).
String formatRelativeAgo(DateTime timestamp, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(timestamp);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// "1h 50m" style duration readout for the fatigue watch card.
String formatDurationShort(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h <= 0) return '${m}m';
  return '${h}h ${m}m';
}
