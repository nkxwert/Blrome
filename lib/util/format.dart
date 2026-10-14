/// 초를 "1시간 5분", "12분", "40초" 같은 문자열로.
String formatDuration(int seconds) {
  if (seconds < 60) return '$seconds초';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h == 0) return '$m분';
  return m == 0 ? '$h시간' : '$h시간 $m분';
}

/// 초를 "0:23:14" 형태로.
String formatHms(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// "10월 14일 (수)".
String formatDayLabel(DateTime t) =>
    '${t.month}월 ${t.day}일 (${_weekdays[t.weekday - 1]})';

/// "13:05".
String formatClock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
