import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../browser/browser_settings.dart';

/// Android 네이티브 광고 차단(요청 단위)과의 연결.
///
/// 웹뷰가 광고 도메인으로 보내는 스크립트·이미지·iframe 요청 자체를 막는다.
/// Android가 아니거나 연결에 실패하면 조용히 넘어간다 (화면 숨기기 방식은 계속 동작).
class NativeAdBlock {
  static const _channel = MethodChannel('blrome/adblock');

  /// [controller]의 웹뷰에 광고 차단을 건다. 내비게이션 델리게이트를 설정한 뒤에 불러야 한다.
  static Future<bool> attach(WebViewController controller) async {
    final platform = controller.platform;
    if (platform is! AndroidWebViewController) return false;
    try {
      return await _channel.invokeMethod<bool>(
              'attach', {'id': platform.webViewIdentifier}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> configure(BrowserSettings settings) async {
    try {
      await _channel.invokeMethod<void>('configure', {
        'enabled': settings.adBlock,
        'exceptions': settings.adBlockExceptions.toList(),
      });
    } catch (_) {}
  }
}
