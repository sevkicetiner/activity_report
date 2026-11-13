const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "2.3" below 10, "68" above: an average like 2/7 must not read as 0.
String formatAverage(num value) =>
    value < 10 ? value.toStringAsFixed(1) : value.round().toString();

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (d > Duration.zero && d < const Duration(minutes: 1)) return '<1m';
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}
