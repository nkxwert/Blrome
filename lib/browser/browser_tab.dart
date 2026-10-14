import 'package:webview_flutter/webview_flutter.dart';

class BrowserTab {
  BrowserTab(this.id, this.url, this.webView);

  final int id;

  /// WebView에 현재 열린 URL.
  String url;
  String title = '';
  double progress = 1;
  bool canGoBack = false;
  bool canGoForward = false;

  /// 데스크톱 사이트로 보기.
  bool desktopMode = false;
  final WebViewController webView;

  /// 차단 화면을 보여 주는 중이면 차단된 원래 URL.
  String? blockedUrl;

  bool get isBlocked => blockedUrl != null;

  /// 주소창에 보여 줄 URL.
  String get displayUrl => blockedUrl ?? url;

  String get host => Uri.tryParse(displayUrl)?.host ?? '';
}
