import 'package:blrome/rules/site_rule.dart';
import 'package:flutter_test/flutter_test.dart';

SiteRule limit(String d, int m) =>
    SiteRule(domain: d, mode: RuleMode.dailyLimit, limitMinutes: m);
SiteRule block(String d) => SiteRule(domain: d, mode: RuleMode.alwaysBlock);

void main() {
  test('느슨해지는 변경', () {
    expect(loosens(limit('a.com', 30), limit('a.com', 60)), isTrue);
    expect(loosens(block('a.com'), limit('a.com', 600)), isTrue);
    expect(loosens(block('a.com'), block('b.com')), isTrue);
  });

  test('엄해지거나 그대로인 변경', () {
    expect(loosens(limit('a.com', 30), limit('a.com', 15)), isFalse);
    expect(loosens(limit('a.com', 30), limit('a.com', 30)), isFalse);
    expect(loosens(limit('a.com', 30), block('a.com')), isFalse);
    expect(loosens(block('a.com'), block('a.com')), isFalse);
  });
}
