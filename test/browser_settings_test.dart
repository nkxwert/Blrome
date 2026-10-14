import 'package:blrome/adblock/adblock.dart';
import 'package:blrome/browser/browser_settings.dart';
import 'package:blrome/storage/storage.dart';
import 'package:blrome/util/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('광고 차단 예외는 하위 도메인까지 적용되고 저장된다', () async {
    final storage = MemoryStorage();
    final s = BrowserSettings(storage)..load();
    expect(s.adBlockEnabledFor('m.naver.com'), isTrue);

    await s.setAdBlockException('naver.com', true);
    expect(s.adBlockEnabledFor('m.naver.com'), isFalse);
    expect(s.adBlockEnabledFor('youtube.com'), isTrue);

    await s.setTextZoom(120);
    final reloaded = BrowserSettings(storage)..load();
    expect(reloaded.adBlockEnabledFor('naver.com'), isFalse);
    expect(reloaded.textZoom, 120);

    await reloaded.setAdBlock(false);
    expect(reloaded.adBlockEnabledFor('youtube.com'), isFalse);
  });

  test('광고 도메인 판별', () {
    expect(isAdHost('securepubads.g.doubleclick.net'), isTrue);
    expect(isAdHost('pagead2.googlesyndication.com'), isTrue);
    expect(isAdHost('www.youtube.com'), isFalse);
    expect(adBlockScript, contains('__blromeAdblock'));
  });

  test('시간 표기', () {
    expect(formatHms(1394), '0:23:14');
    expect(formatHms(3661), '1:01:01');
    expect(formatDayLabel(DateTime(2026, 10, 14)), '10월 14일 (수)');
  });
}
