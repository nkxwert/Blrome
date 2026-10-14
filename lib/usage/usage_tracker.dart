import 'dart:async';

import '../blrome_controller.dart';
import '../rules/site_rule.dart';

/// 화면에 보이는 탭의 사이트 사용 시간을 1초 단위로 센다.
///
/// 앱이 포그라운드이고 [currentHost]가 하루 제한 규칙에 걸릴 때만 센다.
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

    final rule = controller.ruleFor(host);
    if (rule == null || rule.mode != RuleMode.dailyLimit) return;
    if (controller.isUnlockedToday(rule.domain)) return;
    if (controller.decide(host).blocked) return;

    controller.addUsage(rule.domain, 1);

    final after = controller.decide(host);
    if (after.blocked) {
      _save();
      onLimitReached?.call(rule.domain);
      return;
    }
    if (warnAtSeconds.contains(after.remainingSeconds)) {
      onWarning?.call(rule.domain, after.remainingSeconds!);
    }
    if (++_unsaved >= saveEverySeconds) _save();
  }

  void _save() {
    _unsaved = 0;
    controller.flush();
  }
}
