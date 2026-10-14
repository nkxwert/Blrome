/// 초를 "1시간 5분", "12분", "40초" 같은 문자열로.
String formatDuration(int seconds) {
  if (seconds < 60) return '$seconds초';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h == 0) return '$m분';
  return m == 0 ? '$h시간' : '$h시간 $m분';
}
