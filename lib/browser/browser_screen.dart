import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../block/blocked_view.dart';
import '../blrome_controller.dart';
import '../settings/settings_screen.dart';
import '../usage/usage_tracker.dart';
import '../util/format.dart';
import 'browser_tab.dart';
import 'url_utils.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key, required this.controller});

  final BlromeController controller;

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen>
    with WidgetsBindingObserver {
  final List<BrowserTab> _tabs = [];
  int _active = 0;
  int _nextId = 0;

  final _address = TextEditingController();
  final _addressFocus = FocusNode();
  late final UsageTracker _tracker;

  /// 설정 화면이 열려 있는 동안은 사용 시간을 세지 않는다.
  bool _settingsOpen = false;

  BlromeController get _c => widget.controller;
  BrowserTab get _tab => _tabs[_active];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs.add(_createTab(homeUrl));
    _address.text = homeUrl;
    _addressFocus.addListener(_onAddressFocus);
    _c.addListener(_syncBlocking);
    _tracker = UsageTracker(
      controller: _c,
      currentHost: () =>
          _settingsOpen || _tab.isBlocked ? null : Uri.tryParse(_tab.url)?.host,
      onWarning: (domain, remaining) =>
          _snack('$domain 남은 시간 ${formatDuration(remaining)}'),
      onLimitReached: (domain) => _snack('$domain 오늘 사용 시간을 다 썼어요'),
    )..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.removeListener(_syncBlocking);
    _tracker.dispose();
    _address.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _tracker.foreground = state == AppLifecycleState.resumed;
    if (!_tracker.foreground) _c.flush();
  }

  // ---- 차단 ----

  /// 규칙/사용량이 바뀔 때마다 모든 탭의 차단 상태를 다시 맞춘다.
  void _syncBlocking() {
    var changed = false;
    for (final tab in _tabs) {
      if (tab.isBlocked) {
        if (!_c.decideUrl(tab.blockedUrl!).blocked) {
          final url = tab.blockedUrl!;
          tab.blockedUrl = null;
          tab.webView.loadRequest(Uri.parse(url));
          changed = true;
        }
      } else if (_c.decideUrl(tab.url).blocked) {
        _blockTab(tab, tab.url);
        changed = true;
      }
    }
    if (changed && mounted) {
      setState(() {});
      _updateAddress();
    }
  }

  /// [tab]에 차단 화면을 띄우고 페이지는 비워서 영상/소리를 멈춘다.
  void _blockTab(BrowserTab tab, String url) {
    tab.blockedUrl = url;
    tab.webView.loadHtmlString('<html></html>');
  }

  /// WebView의 URL이 바뀔 때마다 호출. 차단 대상이면 막는다.
  void _onUrlChanged(BrowserTab tab, String? url) {
    if (url == null) return;
    // 차단 중에 비운 페이지(about:blank 등)로 바뀌는 건 무시한다.
    if (tab.isBlocked && (Uri.tryParse(url)?.host ?? '').isEmpty) return;
    tab.url = url;
    if (_c.decideUrl(url).blocked) _blockTab(tab, url);
    if (!mounted) return;
    setState(() {});
    if (tab == _tab) _updateAddress();
  }

  // ---- 이동 ----

  void _go(String input) {
    final url = inputToUrl(input);
    _addressFocus.unfocus();
    final tab = _tab;
    if (_c.decideUrl(url).blocked) {
      setState(() => _blockTab(tab, url));
    } else {
      setState(() => tab.blockedUrl = null);
      tab.webView.loadRequest(Uri.parse(url));
    }
    _updateAddress();
  }

  void _goHome() => _go(homeUrl);

  void _updateAddress() {
    if (!_addressFocus.hasFocus) _address.text = _tab.displayUrl;
  }

  void _onAddressFocus() {
    if (_addressFocus.hasFocus) {
      _address.selection =
          TextSelection(baseOffset: 0, extentOffset: _address.text.length);
    } else {
      _updateAddress();
    }
  }

  Future<void> _handleBack() async {
    final web = _tab.webView;
    if (_tab.isBlocked) {
      _goHome();
    } else if (await web.canGoBack()) {
      await web.goBack();
    } else {
      await SystemNavigator.pop();
    }
  }

  // ---- 탭 ----

  BrowserTab _createTab(String url) {
    late final BrowserTab tab;
    final web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          if (!request.isMainFrame) return NavigationDecision.navigate;
          if (_c.decideUrl(request.url).blocked) {
            setState(() => _blockTab(tab, request.url));
            if (tab == _tab) _updateAddress();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageStarted: (url) => _onUrlChanged(tab, url),
        onUrlChange: (change) => _onUrlChanged(tab, change.url),
        onProgress: (p) {
          if (mounted) setState(() => tab.progress = p / 100);
        },
        onPageFinished: (_) async {
          tab.title = await tab.webView.getTitle() ?? '';
          tab.canGoBack = await tab.webView.canGoBack();
          tab.canGoForward = await tab.webView.canGoForward();
          if (mounted) setState(() {});
        },
      ));
    tab = BrowserTab(_nextId++, url, web);
    web.loadRequest(Uri.parse(url));
    return tab;
  }

  void _newTab() {
    setState(() {
      _tabs.add(_createTab(homeUrl));
      _active = _tabs.length - 1;
    });
    _updateAddress();
  }

  void _closeTab(int index) {
    setState(() {
      _tabs.removeAt(index);
      if (_tabs.isEmpty) _tabs.add(_createTab(homeUrl));
      if (_active >= _tabs.length) _active = _tabs.length - 1;
      if (index < _active) _active--;
    });
    _updateAddress();
  }

  void _selectTab(int index) {
    setState(() => _active = index);
    _updateAddress();
  }

  Future<void> _showTabs() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (var i = 0; i < _tabs.length; i++)
                ListTile(
                  selected: i == _active,
                  leading: Icon(_tabs[i].isBlocked ? Icons.block : Icons.public),
                  title: Text(
                    _tabs[i].title.isEmpty ? _tabs[i].host : _tabs[i].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_tabs[i].displayUrl,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _closeTab(i);
                      setSheet(() {});
                    },
                  ),
                  onTap: () {
                    _selectTab(i);
                    Navigator.pop(context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('새 탭'),
                onTap: () {
                  _newTab();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    _settingsOpen = true;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SettingsScreen(controller: _c),
    ));
    _settingsOpen = false;
    _syncBlocking();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- 화면 ----

  @override
  Widget build(BuildContext context) {
    final tab = _tab;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildToolbar(context),
              if (tab.progress < 1 && !tab.isBlocked)
                LinearProgressIndicator(value: tab.progress, minHeight: 2),
              Expanded(
                child: Stack(
                  children: [
                    IndexedStack(
                      index: _active,
                      children: [
                        for (final t in _tabs) _buildWebView(t),
                      ],
                    ),
                    if (tab.isBlocked) _buildBlocked(tab),
                  ],
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _address,
              focusNode: _addressFocus,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              onSubmitted: _go,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Google 검색 또는 URL 입력',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          _RemainingChip(controller: _c, url: () => _tab.displayUrl),
        ],
      ),
    );
  }

  Widget _buildWebView(BrowserTab tab) {
    return WebViewWidget(key: ValueKey(tab.id), controller: tab.webView);
  }

  Widget _buildBlocked(BrowserTab tab) {
    final decision = _c.decideUrl(tab.blockedUrl!);
    final rule = decision.rule;
    if (rule == null || decision.reason == null) return const SizedBox.shrink();
    return BlockedView(
      domain: rule.domain,
      reason: decision.reason!,
      limitMinutes: rule.limitMinutes,
      onGoHome: _goHome,
      onOpenSettings: _openSettings,
    );
  }

  Widget _buildBottomBar() {
    final tab = _tab;
    return BottomAppBar(
      height: 56,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            tooltip: '뒤로',
            icon: const Icon(Icons.arrow_back),
            onPressed: tab.canGoBack || tab.isBlocked ? _handleBack : null,
          ),
          IconButton(
            tooltip: '앞으로',
            icon: const Icon(Icons.arrow_forward),
            onPressed: tab.canGoForward && !tab.isBlocked
                ? () => tab.webView.goForward()
                : null,
          ),
          IconButton(
            tooltip: '홈',
            icon: const Icon(Icons.home_outlined),
            onPressed: _goHome,
          ),
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: tab.isBlocked ? null : () => tab.webView.reload(),
          ),
          IconButton(
            tooltip: '탭',
            onPressed: _showTabs,
            icon: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${_tabs.length}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
          IconButton(
            tooltip: '차단 설정',
            icon: const Icon(Icons.timer_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
    );
  }
}

/// 주소창 옆에 현재 사이트의 오늘 남은 시간을 보여 준다.
class _RemainingChip extends StatelessWidget {
  const _RemainingChip({required this.controller, required this.url});

  final BlromeController controller;
  final String Function() url;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final remaining = controller.decideUrl(url()).remainingSeconds;
        if (remaining == null) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        final low = remaining <= 300;
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Chip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(Icons.hourglass_bottom,
                size: 16, color: low ? scheme.onError : null),
            label: Text(formatDuration(remaining)),
            backgroundColor: low ? scheme.error : null,
            labelStyle: low ? TextStyle(color: scheme.onError) : null,
          ),
        );
      },
    );
  }
}
