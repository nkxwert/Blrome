import 'site_rule.dart';

/// 사용자가 입력한 값을 규칙용 도메인으로 정규화한다.
///
/// "https://www.YouTube.com/watch?v=1" → "youtube.com".
/// 올바른 도메인이 아니면 null.
String? normalizeDomain(String input) {
  var s = input.trim().toLowerCase();
  if (s.isEmpty) return null;
  s = s.replaceFirst(RegExp(r'^[a-z][a-z0-9+.-]*://'), '');
  s = s.split(RegExp(r'[/?#]')).first;
  s = s.split('@').last; // user:pass@host
  s = s.split(':').first; // 포트
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  if (s.startsWith('www.')) s = s.substring(4);
  final valid = RegExp(r'^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9-]{2,}$');
  return valid.hasMatch(s) ? s : null;
}

/// [host]가 [domain] 자체이거나 그 하위 도메인이면 true.
bool hostMatches(String host, String domain) {
  final h = host.toLowerCase();
  return h == domain || h.endsWith('.$domain');
}

/// [host]에 적용되는 규칙. 여러 개가 맞으면 가장 구체적인(긴) 도메인을 고른다.
SiteRule? findRule(String host, Iterable<SiteRule> rules) {
  SiteRule? best;
  for (final rule in rules) {
    if (hostMatches(host, rule.domain) &&
        (best == null || rule.domain.length > best.domain.length)) {
      best = rule;
    }
  }
  return best;
}
