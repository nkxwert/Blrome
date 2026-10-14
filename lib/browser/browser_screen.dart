import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../adblock/adblock.dart';
import '../adblock/native_adblock.dart';
import '../block/blocked_view.dart';
import '../blrome_controller.dart';
import '../history/history_screen.dart';
import '../history/history_store.dart';
import '../rules/domain_matcher.dart';
import '../rules/site_rule.dart';
import '../settings/rule_edit_dialog.dart';
import '../settings/settings_screen.dart';
import '../stats/usage_stats_screen.dart';
import '../usage/usage_tracker.dart';
import '../util/format.dart';
import 'address_bar.dart';
import 'browser_settings.dart';
import 'browser_tab.dart';
import 'url_utils.dart';

const _desktopUserAgent =
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/141.0.0.0 Safari/537.36';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({
    super.key,
    required this.controller,
    required this.settings,
    required this.history,
  });

  final BlromeController controller;
  final BrowserSettings settings;
  final HistoryStore history;

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
  final _cookies = WebViewCookieManager();
  late final UsageTracker _tracker;

  /// 설정·기록 같은 다른 화면이 열려 있는 동안은 사용 시간을 세지 않는다.
  bool _pageOpen = false;

  BlromeController get _c => widget.controller;
  BrowserSettings get _settings => widget.settings;
  BrowserTab get _tab => _tabs[_active];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs.add(_createTab(homeUrl));
    _address.text = homeUrl;
    _addressFocus.addListener(_onAddressFocus);
    _c.addListener(_syncBlocking);
    _settings.addListener(_applySettings);
    NativeAdBlock.configure(_settings);
    _tracker = UsageTracker(
      controller: _c,
      currentHost: () {
        if (_pageOpen || _tab.isBlocked) return null;
        final uri = Uri.tryParse(_tab.url);
        return uri != null && (uri.scheme == 'http' || uri.scheme == 'https')
            ? uri.host
            : null;
      },
      onWarning: (domain, remaining) =>
          _snack('$domain 남은 시간 ${formatDuration(remaining)}'),
      onLimitReached: (domain) => _snack('$domain 오늘 사용 시간을 다 썼어요'),
    )..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.removeListener(_syncBlocking);
    _settings.removeListener(_applySettings);
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

  // ---- 탭 생성과 웹뷰 설정 ----

  BrowserTab _createTab(String url) {
    final tab = BrowserTab(_nextId++, url, WebViewController());
    _initTab(tab, url);
    return tab;
  }

  /// 웹뷰를 설정하고 [url]을 연다. 광고 차단 래퍼는 델리게이트를 설정한 뒤에 걸어야
  /// 하므로 순서대로 기다린다.
  Future<void> _initTab(BrowserTab tab, String url) async {
    final web = tab.webView;
    await web.setJavaScriptMode(JavaScriptMode.unrestricted);
    await web.setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (request) {
        if (!request.isMainFrame) return NavigationDecision.navigate;
        final host = Uri.tryParse(request.url)?.host ?? '';
        // 광고 링크로 페이지 전체가 넘어가는 것(팝업 광고 등)을 막는다.
        if (isAdHost(host) && _settings.adBlockEnabledFor(tab.host)) {
          return NavigationDecision.prevent;
        }
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
        _injectAdBlock(tab);
        if (mounted) setState(() => tab.progress = p / 100);
      },
      onPageFinished: (url) async {
        _injectAdBlock(tab);
        tab.title = await web.getTitle() ?? '';
        tab.canGoBack = await web.canGoBack();
        tab.canGoForward = await web.canGoForward();
        if (!tab.isBlocked) widget.history.add(url, tab.title);
        if (mounted) setState(() {});
      },
    ));
    await NativeAdBlock.attach(web);
    _applySettingsTo(tab);
    if (tab.url == url && !tab.isBlocked) await web.loadRequest(Uri.parse(url));
  }

  void _applySettingsTo(BrowserTab tab) {
    final platform = tab.webView.platform;
    if (platform is AndroidWebViewController) {
      platform.setTextZoom(_settings.textZoom);
      // Chrome처럼 페이지의 viewport 설정을 따른다. 데스크톱 사이트 보기에 필요.
      platform.setUseWideViewPort(true);
      platform.setMediaPlaybackRequiresUserGesture(true);
      final cookies = _cookies.platform;
      if (cookies is AndroidWebViewCookieManager) {
        cookies.setAcceptThirdPartyCookies(platform, _settings.thirdPartyCookies);
      }
    }
  }

  void _applySettings() {
    NativeAdBlock.configure(_settings);
    for (final tab in _tabs) {
      _applySettingsTo(tab);
    }
  }

  void _injectAdBlock(BrowserTab tab) {
    if (tab.isBlocked) return;
    final uri = Uri.tryParse(tab.url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) return;
    if (!_settings.adBlockEnabledFor(uri.host)) return;
    tab.webView.runJavaScript(adBlockScript).catchError((_) {});
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
                  dense: true,
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
                dense: true,
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

  // ---- 다른 화면 ----

  Future<T?> _push<T>(Widget page) async {
    _pageOpen = true;
    final result =
        await Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
    _pageOpen = false;
    _syncBlocking();
    return result;
  }

  Future<void> _openRules() => _push<void>(SettingsScreen(controller: _c));

  Future<void> _openStats() => _push<void>(UsageStatsScreen(controller: _c));

  Future<void> _openHistory() async {
    final url = await _push<String>(HistoryScreen(history: widget.history));
    if (url != null) _go(url);
  }

  // ---- 메뉴 / 시트 ----

  void _toggleDesktop() {
    final tab = _tab;
    setState(() => tab.desktopMode = !tab.desktopMode);
    tab.webView.setUserAgent(tab.desktopMode ? _desktopUserAgent : null);
    if (!tab.isBlocked) tab.webView.reload();
  }

  Future<void> _toggleAdBlock() async {
    await _settings.setAdBlock(!_settings.adBlock);
    _snack(_settings.adBlock ? '광고 차단을 켰어요' : '광고 차단을 껐어요');
    if (!_tab.isBlocked) _tab.webView.reload();
  }

  Future<void> _showMenu() async {
    final tab = _tab;
    void run(VoidCallback action) {
      Navigator.pop(context);
      action();
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            childAspectRatio: 1.1,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _MenuTile(
                icon: Icons.timer_outlined,
                label: '차단·시간 설정',
                onTap: () => run(_openRules),
              ),
              _MenuTile(
                icon: Icons.bar_chart,
                label: '사용 시간',
                onTap: () => run(_openStats),
              ),
              _MenuTile(
                icon: Icons.history,
                label: '방문 기록',
                onTap: () => run(_openHistory),
              ),
              _MenuTile(
                icon: Icons.add_box_outlined,
                label: '새 탭',
                onTap: () => run(_newTab),
              ),
              _MenuTile(
                icon: Icons.desktop_windows_outlined,
                label: '데스크톱 사이트',
                selected: tab.desktopMode,
                onTap: () => run(_toggleDesktop),
              ),
              _MenuTile(
                icon: Icons.shield_outlined,
                label: '광고 차단',
                selected: _settings.adBlock,
                onTap: () => run(_toggleAdBlock),
              ),
              _MenuTile(
                icon: Icons.cookie_outlined,
                label: '쿠키·데이터',
                onTap: () => run(_showCookieSheet),
              ),
              _MenuTile(
                icon: Icons.format_size,
                label: '글자 크기',
                onTap: () => run(_showTextZoom),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSiteInfo() async {
    final tab = _tab;
    final uri = Uri.tryParse(tab.displayUrl);
    final host = uri?.host ?? '';
    if (host.isEmpty) return;
    final secure = uri!.scheme == 'https';
    final siteDomain = normalizeDomain(host) ?? host;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_c, _settings]),
          builder: (context, _) {
            final rule = _c.ruleFor(host);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(secure ? Icons.lock_outline : Icons.lock_open,
                      color: secure ? null : Theme.of(context).colorScheme.error),
                  title: Text(host),
                  subtitle: Text(secure ? '보안 연결(https)' : '보안되지 않은 연결'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(rule == null ? '이 사이트 시간 제한 추가' : '시간 제한'),
                  subtitle: rule == null
                      ? null
                      : Text(rule.mode == RuleMode.alwaysBlock
                          ? '${rule.domain} · 항상 차단'
                          : '${rule.domain} · 하루 ${formatDuration(rule.limitSeconds!)}'),
                  onTap: () async {
                    Navigator.pop(context);
                    if (rule != null) return _openRules();
                    final created =
                        await showRuleEditDialog(this.context, domain: siteDomain);
                    if (created != null) await _c.upsertRule(created);
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.shield_outlined),
                  title: const Text('이 사이트 광고 차단'),
                  subtitle: _settings.adBlock ? null : const Text('광고 차단이 꺼져 있어요'),
                  value: _settings.adBlockEnabledFor(host),
                  onChanged: _settings.adBlock
                      ? (v) async {
                          await _settings.setAdBlockException(siteDomain, !v);
                          tab.webView.reload();
                        }
                      : null,
                ),
                ListTile(
                  leading: const Icon(Icons.cookie_outlined),
                  title: const Text('쿠키·사이트 데이터'),
                  onTap: () {
                    Navigator.pop(context);
                    _showCookieSheet();
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCookieSheet() async {
    Future<void> done(BuildContext sheet, Future<void> work, String message) async {
      await work;
      if (sheet.mounted) Navigator.pop(sheet);
      _snack(message);
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListenableBuilder(
          listenable: _settings,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.cookie_outlined),
                title: const Text('다른 사이트 쿠키 허용'),
                subtitle: const Text('끄면 일부 로그인·임베드가 동작하지 않을 수 있어요'),
                value: _settings.thirdPartyCookies,
                onChanged: _settings.setThirdPartyCookies,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('모든 쿠키 삭제'),
                subtitle: const Text('모든 사이트에서 로그아웃돼요'),
                onTap: () => done(context, _cookies.clearCookies(), '쿠키를 삭제했어요'),
              ),
              ListTile(
                leading: const Icon(Icons.cached),
                title: const Text('캐시 삭제'),
                onTap: () => done(context, _tab.webView.clearCache(), '캐시를 삭제했어요'),
              ),
              ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('사이트 저장소 삭제'),
                subtitle: const Text('모든 사이트의 로컬 저장 데이터를 지워요'),
                onTap: () => done(
                    context, _tab.webView.clearLocalStorage(), '사이트 저장소를 삭제했어요'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTextZoom() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListenableBuilder(
          listenable: _settings,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('웹페이지 글자 크기 ${_settings.textZoom}%',
                    style: Theme.of(context).textTheme.titleMedium),
                Slider(
                  min: 50,
                  max: 200,
                  divisions: 15,
                  value: _settings.textZoom.toDouble(),
                  label: '${_settings.textZoom}%',
                  onChanged: (v) => _settings.setTextZoom(v.round()),
                ),
                TextButton(
                  onPressed: () => _settings.setTextZoom(100),
                  child: const Text('기본값(100%)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
              SizedBox(
                height: 2,
                child: tab.progress < 1 && !tab.isBlocked
                    ? LinearProgressIndicator(value: tab.progress, minHeight: 2)
                    : null,
              ),
              Expanded(
                child: Stack(
                  children: [
                    IndexedStack(
                      index: _active,
                      children: [
                        for (final t in _tabs)
                          WebViewWidget(key: ValueKey(t.id), controller: t.webView),
                      ],
                    ),
                    if (tab.isBlocked) _buildBlocked(tab),
                  ],
                ),
              ),
              _buildBottomBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final tab = _tab;
    final secure = Uri.tryParse(tab.displayUrl)?.scheme == 'https';
    return AddressBar(
      controller: _address,
      focusNode: _addressFocus,
      onSubmitted: _go,
      leadingIcon: tab.isBlocked
          ? Icons.block
          : secure
              ? Icons.lock_outline
              : Icons.info_outline,
      onLeadingPressed: _showSiteInfo,
      trailing: [
        _RemainingChip(controller: _c, url: () => _tab.displayUrl),
        IconButton(
          tooltip: '새로고침',
          iconSize: 22,
          icon: const Icon(Icons.refresh),
          onPressed: tab.isBlocked ? null : () => tab.webView.reload(),
        ),
      ],
    );
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
      onOpenSettings: _openRules,
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final tab = _tab;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(top: BorderSide(color: scheme.outlineVariant, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            tooltip: '뒤로',
            iconSize: 22,
            icon: const Icon(Icons.arrow_back),
            onPressed: tab.canGoBack || tab.isBlocked ? _handleBack : null,
          ),
          IconButton(
            tooltip: '앞으로',
            iconSize: 22,
            icon: const Icon(Icons.arrow_forward),
            onPressed: tab.canGoForward && !tab.isBlocked
                ? () => tab.webView.goForward()
                : null,
          ),
          IconButton(
            tooltip: '홈',
            iconSize: 22,
            icon: const Icon(Icons.home_outlined),
            onPressed: _goHome,
          ),
          IconButton(
            tooltip: '탭',
            onPressed: _showTabs,
            icon: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: scheme.onSurface, width: 1.6),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text('${_tabs.length}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          IconButton(
            tooltip: '메뉴',
            iconSize: 22,
            icon: const Icon(Icons.menu),
            onPressed: _showMenu,
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 22, color: selected ? scheme.onPrimaryContainer : null),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
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
        return Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: low ? scheme.error : scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_bottom,
                  size: 14,
                  color: low ? scheme.onError : scheme.onSecondaryContainer),
              const SizedBox(width: 2),
              Text(
                formatDuration(remaining),
                style: TextStyle(
                  fontSize: 12,
                  color: low ? scheme.onError : scheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
