import 'package:blrome/blrome_controller.dart';
import 'package:blrome/history/history_screen.dart';
import 'package:blrome/history/history_store.dart';
import 'package:blrome/rules/site_rule.dart';
import 'package:blrome/settings/rule_edit_dialog.dart';
import 'package:blrome/settings/settings_screen.dart';
import 'package:blrome/stats/usage_stats_screen.dart';
import 'package:blrome/storage/storage.dart';
import 'package:blrome/widgets/hold_confirm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpPhone(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: home));
}

void main() {
  testWidgets('사용 시간 화면: 목록과 시간표', (tester) async {
    var now = DateTime(2026, 10, 14, 8, 15);
    final c = BlromeController(MemoryStorage(), clock: () => now)..load();
    c.addUsage('youtube.com', 600);
    now = DateTime(2026, 10, 14, 8, 25);
    c.addUsage('a-very-long-site-name.example.com', 794);

    await pumpPhone(tester, UsageStatsScreen(controller: c));
    expect(find.text('youtube.com'), findsOneWidget);
    expect(find.text('0:13:14'), findsOneWidget);
    expect(find.text('23분'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('방문 기록 화면', (tester) async {
    final h = HistoryStore(MemoryStorage())..load();
    await h.add('https://example.com/page', 'Example');
    await pumpPhone(tester, HistoryScreen(history: h));
    expect(find.text('Example'), findsOneWidget);
  });

  testWidgets('규칙 다이얼로그: 다이얼과 프리셋', (tester) async {
    SiteRule? result;
    await pumpPhone(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              result = await showRuleEditDialog(context, domain: 'youtube.com'),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1시간'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(result?.domain, 'youtube.com');
    expect(result?.limitMinutes, 60);
  });

  testWidgets('꾹 누르기: 중간에 떼면 실패, 끝까지 누르면 확인', (tester) async {
    bool? result;
    await pumpPhone(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showHoldConfirm(context,
              title: 't', message: 'm', action: '해제'),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final button = find.byIcon(Icons.touch_app);
    var gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(result, isNull);

    gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(); // 애니메이션 시작 프레임
    await tester.pump(const Duration(seconds: 9));
    expect(result, isNull);
    await tester.pump(const Duration(seconds: 2));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('설정 화면: 규칙 목록', (tester) async {
    final c = BlromeController(MemoryStorage())..load();
    await c.upsertRule(const SiteRule(
        domain: 'youtube.com', mode: RuleMode.dailyLimit, limitMinutes: 30));
    await pumpPhone(tester, SettingsScreen(controller: c));
    expect(find.text('youtube.com'), findsOneWidget);
  });
}
