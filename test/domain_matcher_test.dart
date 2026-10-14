import 'package:blrome/rules/domain_matcher.dart';
import 'package:blrome/rules/site_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeDomain', () {
    test('스킴, www, 경로, 포트, 대문자를 정리한다', () {
      expect(normalizeDomain('https://www.YouTube.com/watch?v=1'), 'youtube.com');
      expect(normalizeDomain('m.youtube.com:443/'), 'm.youtube.com');
      expect(normalizeDomain('  instagram.com  '), 'instagram.com');
      expect(normalizeDomain('naver.com.'), 'naver.com');
    });

    test('도메인이 아니면 null', () {
      expect(normalizeDomain(''), isNull);
      expect(normalizeDomain('youtube'), isNull);
      expect(normalizeDomain('you tube.com'), isNull);
    });
  });

  group('hostMatches', () {
    test('자기 자신과 하위 도메인만 매칭', () {
      expect(hostMatches('youtube.com', 'youtube.com'), isTrue);
      expect(hostMatches('m.youtube.com', 'youtube.com'), isTrue);
      expect(hostMatches('WWW.YOUTUBE.COM', 'youtube.com'), isTrue);
      expect(hostMatches('notyoutube.com', 'youtube.com'), isFalse);
      expect(hostMatches('youtube.com.evil.io', 'youtube.com'), isFalse);
    });
  });

  test('findRule은 가장 구체적인 규칙을 고른다', () {
    const google = SiteRule(domain: 'google.com', mode: RuleMode.alwaysBlock);
    const mail = SiteRule(
        domain: 'mail.google.com', mode: RuleMode.dailyLimit, limitMinutes: 10);
    expect(findRule('mail.google.com', [google, mail]), same(mail));
    expect(findRule('www.google.com', [mail, google]), same(google));
    expect(findRule('naver.com', [mail, google]), isNull);
  });
}
