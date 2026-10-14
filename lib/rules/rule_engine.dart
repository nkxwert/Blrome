import 'site_rule.dart';

enum BlockReason { alwaysBlocked, limitReached }

/// 어떤 호스트에 접속해도 되는지에 대한 판단 결과.
class SiteDecision {
  const SiteDecision.allowed({this.rule, this.remainingSeconds}) : reason = null;
  const SiteDecision.blocked(this.rule, BlockReason this.reason)
      : remainingSeconds = 0;

  /// 적용된 규칙. 규칙이 없으면 null.
  final SiteRule? rule;

  /// 차단된 이유. 허용이면 null.
  final BlockReason? reason;

  /// 하루 제한 규칙일 때 오늘 남은 시간(초). 그 외에는 null.
  final int? remainingSeconds;

  bool get blocked => reason != null;
}

/// 규칙, 오늘 사용량, 오늘 해제 여부로 판단한다.
SiteDecision evaluate(
  SiteRule? rule, {
  required int usedSecondsToday,
  required bool unlockedToday,
}) {
  if (rule == null || unlockedToday) return SiteDecision.allowed(rule: rule);
  switch (rule.mode) {
    case RuleMode.alwaysBlock:
      return SiteDecision.blocked(rule, BlockReason.alwaysBlocked);
    case RuleMode.dailyLimit:
      final remaining = rule.limitSeconds! - usedSecondsToday;
      if (remaining <= 0) {
        return SiteDecision.blocked(rule, BlockReason.limitReached);
      }
      return SiteDecision.allowed(rule: rule, remainingSeconds: remaining);
  }
}
