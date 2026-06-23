import 'package:intl/intl.dart';

final _time = DateFormat('h:mm a');

String formatTime(DateTime t) => _time.format(t).toLowerCase();

String formatDurationMinutes(int minutes) {
  if (minutes < 1) return 'now';
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// Live stopwatch style: "0:42", "12:05", "1:23:04". Used for the running
/// sleep timer that ticks every second.
String formatStopwatch(Duration d) {
  final total = d.isNegative ? Duration.zero : d;
  final hours = total.inHours;
  final minutes = total.inMinutes.remainder(60);
  final seconds = total.inSeconds.remainder(60);
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    final mm = minutes.toString().padLeft(2, '0');
    return '$hours:$mm:$ss';
  }
  return '$minutes:$ss';
}

/// "in 42 min" / "now" / "23 min ago"
String formatRelative(DateTime target, DateTime now) {
  final diff = target.difference(now).inMinutes;
  if (diff.abs() < 1) return 'now';
  if (diff > 0) return 'in ${formatDurationMinutes(diff)}';
  return '${formatDurationMinutes(-diff)} ago';
}
