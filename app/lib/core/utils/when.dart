const kMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const kWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

int _dayDiff(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.difference(DateTime(d.year, d.month, d.day)).inDays;
}

String _hm(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ap = d.hour < 12 ? 'AM' : 'PM';
  return '$h:${d.minute.toString().padLeft(2, '0')} $ap';
}

/// "Today, 10:15 AM" / "Yesterday, 4:30 PM" / "Sep 12, 8:00 AM"
String fmtWhen(DateTime d) {
  final diff = _dayDiff(d);
  if (diff == 0) return 'Today, ${_hm(d)}';
  if (diff == 1) return 'Yesterday, ${_hm(d)}';
  return '${kMonths[d.month - 1]} ${d.day}, ${_hm(d)}';
}

/// Group header for the activity feed: "Today" / "Yesterday" / "Tue, Sep 12"
String fmtDay(DateTime d) {
  final diff = _dayDiff(d);
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${kWeekdays[d.weekday - 1]}, ${kMonths[d.month - 1]} ${d.day}';
}

String monthTitle(DateTime d) => '${kMonths[d.month - 1]} ${d.year}';
