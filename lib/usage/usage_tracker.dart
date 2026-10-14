import 'dart:async';

import '../blrome_controller.dart';

/// 화면에 보이는 탭의 사이트 사용 시간을 1초 단위로 센다.
///
/// 앱이 포그라운드일 때 [currentHost]의 사이트 시간을 쌓고,
/// 하루 제한이 걸린 사이트면 경고·차단 시점을 알린다.
class UsageTracker {
  UsageTracker({
    required this.controller,
    required this.currentHost,
    this.onWarning,
    this.onLimitReached,
    this.saveEverySeconds = 10,
  });

  final BlromeController controller;

  /// 지금 사용자가 보고 있는 탭의 호스트. 없거나 차단 화면이면 null.
  final String? Function() currentHost;

  /// 남은 시간이 [warnAtSeconds] 중 하나가 되면 호출된다.
  final void Function(String domain, int remainingSeconds)? onWarning;
  final void Function(String domain)? onLimitReached;
  final int saveEverySeconds;

  static const warnAtSeconds = {300, 60};

  /// 앱이 화면에 떠 있는지. 앱 생명주기에 맞춰 바깥에서 바꿔 준다.
  bool foreground = true;

  Timer? _timer;
  int _unsaved = 0;

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    controller.flush();
  }

  /// 1초 분량을 처리한다. 테스트에서 직접 호출할 수 있다.
  void tick() {
    if (!foreground) return;
    final host = currentHost();
    if (host == null || host.isEmpty) return;

    final before = controller.decide(host);
    if (before.blocked) return;

    final site = controller.siteKeyFor(host);
    controller.addUsage(site, 1);

    // 하루 제한이 걸린(그리고 오늘 해제하지 않은) 사이트만 남은 시간을 본다.
    if (before.remainingSeconds != null) {
      final after = controller.decide(host);
      if (after.blocked) {
        _save();
        onLimitReached?.call(site);
        return;
      }
      if (warnAtSeconds.contains(after.remainingSeconds)) {
        onWarning?.call(site, after.remainingSeconds!);
      }
    }
    if (++_unsaved >= saveEverySeconds) _save();
  }

  void _save() {
    _unsaved = 0;
    controller.flush();
  }
}
