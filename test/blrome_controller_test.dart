import 'package:blrome/blrome_controller.dart';
import 'package:blrome/rules/rule_engine.dart';
import 'package:blrome/rules/site_rule.dart';
import 'package:blrome/storage/storage.dart';
import 'package:blrome/usage/usage_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryStorage storage;
  late DateTime now;
  late BlromeController c;

  BlromeController newController() =>
      BlromeController(storage, clock: () => now)..load();

  setUp(() {
    storage = MemoryStorage();
    now = DateTime(2026, 10, 14, 23, 50);
    c = newController();
  });

  test('규칙이 없으면 허용', () {
    expect(c.decide('youtube.com').blocked, isFalse);
  });

  test('항상 차단 규칙은 하위 도메인까지 막는다', () async {
    await c.upsertRule(
        const SiteRule(domain: 'instagram.com', mode: RuleMode.alwaysBlock));
    final d = c.decideUrl('https://www.instagram.com/explore');
    expect(d.blocked, isTrue);
    expect(d.reason, BlockReason.alwaysBlocked);
  });

  test('하루 제한: 다 쓰면 막히고 자정에 풀린다', () async {
    await c.upsertRule(const SiteRule(
        domain: 'youtube.com', mode: RuleMode.dailyLimit, limitMinutes: 30));

    c.addUsage('youtube.com', 29 * 60);
    expect(c.decide('m.youtube.com').remainingSeconds, 60);

    c.addUsage('youtube.com', 60);
    expect(c.decide('m.youtube.com').reason, BlockReason.limitReached);

    now = DateTime(2026, 10, 15, 0, 0, 1);
    expect(c.decide('m.youtube.com').blocked, isFalse);
    expect(c.decide('youtube.com').remainingSeconds, 30 * 60);
  });

  test('오늘만 해제는 자정에 사라진다', () async {
    await c.upsertRule(
        const SiteRule(domain: 'x.com', mode: RuleMode.alwaysBlock));
    await c.unlockToday('x.com');
    expect(c.decide('x.com').blocked, isFalse);

    now = now.add(const Duration(minutes: 20));
    expect(c.decide('x.com').blocked, isTrue);
  });

  test('저장 후 다시 불러와도 규칙, 사용량, 해제가 유지된다', () async {
    await c.upsertRule(const SiteRule(
        domain: 'youtube.com', mode: RuleMode.dailyLimit, limitMinutes: 10));
    await c.upsertRule(
        const SiteRule(domain: 'x.com', mode: RuleMode.alwaysBlock));
    await c.unlockToday('x.com');
    c.addUsage('youtube.com', 125);
    await c.flush();

    final reloaded = newController();
    expect(reloaded.rules.map((r) => r.domain), ['x.com', 'youtube.com']);
    expect(reloaded.usedSecondsToday('youtube.com'), 125);
    expect(reloaded.isUnlockedToday('x.com'), isTrue);
  });

  test('도메인을 바꿔 수정하면 이전 규칙은 지워진다', () async {
    const old = SiteRule(domain: 'a.com', mode: RuleMode.alwaysBlock);
    await c.upsertRule(old);
    await c.upsertRule(
        const SiteRule(domain: 'b.com', mode: RuleMode.alwaysBlock),
        replacing: 'a.com');
    expect(c.rules.map((r) => r.domain), ['b.com']);
  });

  group('UsageTracker', () {
    late String? host;
    late List<String> events;
    late UsageTracker tracker;

    setUp(() async {
      await c.upsertRule(const SiteRule(
          domain: 'youtube.com', mode: RuleMode.dailyLimit, limitMinutes: 6));
      host = 'm.youtube.com';
      events = [];
      tracker = UsageTracker(
        controller: c,
        currentHost: () => host,
        onWarning: (d, s) => events.add('warn $d $s'),
        onLimitReached: (d) => events.add('limit $d'),
      );
    });

    void ticks(int n) {
      for (var i = 0; i < n; i++) {
        tracker.tick();
      }
    }

    test('보고 있는 제한 사이트만 세고, 경고 후 차단한다', () {
      ticks(60);
      expect(c.usedSecondsToday('youtube.com'), 60);
      expect(events, ['warn youtube.com 300']);

      host = 'naver.com';
      ticks(10);
      expect(c.usedSecondsToday('youtube.com'), 60);

      host = 'youtube.com';
      tracker.foreground = false;
      ticks(10);
      expect(c.usedSecondsToday('youtube.com'), 60);

      tracker.foreground = true;
      ticks(400);
      expect(c.usedSecondsToday('youtube.com'), 360);
      expect(events, [
        'warn youtube.com 300',
        'warn youtube.com 60',
        'limit youtube.com',
      ]);
      expect(c.decide('youtube.com').blocked, isTrue);
    });

    test('주기적으로 저장한다', () {
      ticks(10);
      expect(newController().usedSecondsToday('youtube.com'), 10);
    });
  });
}
