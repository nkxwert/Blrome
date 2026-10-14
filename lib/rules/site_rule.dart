/// 도메인 하나에 대한 차단 규칙.
enum RuleMode {
  /// 항상 차단.
  alwaysBlock,

  /// 하루 [SiteRule.limitMinutes]분까지만 허용. 자정에 초기화.
  dailyLimit,
}

class SiteRule {
  const SiteRule({
    required this.domain,
    required this.mode,
    this.limitMinutes,
  }) : assert(mode != RuleMode.dailyLimit || limitMinutes != null);

  /// 정규화된 도메인 (예: "youtube.com"). 하위 도메인에도 적용된다.
  final String domain;
  final RuleMode mode;

  /// [RuleMode.dailyLimit]일 때 하루 허용 시간(분).
  final int? limitMinutes;

  int? get limitSeconds => limitMinutes == null ? null : limitMinutes! * 60;

  Map<String, dynamic> toJson() => {
        'domain': domain,
        'mode': mode.name,
        if (limitMinutes != null) 'limitMinutes': limitMinutes,
      };

  factory SiteRule.fromJson(Map<String, dynamic> json) => SiteRule(
        domain: json['domain'] as String,
        mode: RuleMode.values.byName(json['mode'] as String),
        limitMinutes: json['limitMinutes'] as int?,
      );
}
