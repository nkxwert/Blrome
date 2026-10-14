import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class BrowserTab {
  BrowserTab(this.id, this.url);

  final int id;

  /// WebView에 현재 열린 URL.
  String url;
  String title = '';
  double progress = 1;
  bool canGoBack = false;
  bool canGoForward = false;
  InAppWebViewController? webView;

  /// 차단 화면을 보여 주는 중이면 차단된 원래 URL.
  String? blockedUrl;

  bool get isBlocked => blockedUrl != null;

  /// 주소창에 보여 줄 URL.
  String get displayUrl => blockedUrl ?? url;

  String get host => Uri.tryParse(displayUrl)?.host ?? '';
}
