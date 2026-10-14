import '../rules/domain_matcher.dart';

/// 광고를 내보내는 도메인. 이 도메인의 iframe/이미지는 지우고,
/// 페이지 자체가 이쪽으로 이동하려 하면 막는다.
const adDomains = [
  'doubleclick.net',
  'googlesyndication.com',
  'googleadservices.com',
  'adservice.google.com',
  'pagead2.googlesyndication.com',
  'amazon-adsystem.com',
  'adnxs.com',
  'taboola.com',
  'outbrain.com',
  'criteo.com',
  'criteo.net',
  'pubmatic.com',
  'rubiconproject.com',
  'openx.net',
  'adsrvr.org',
  'moatads.com',
  'smartadserver.com',
  'adform.net',
  'media.net',
  'yieldmo.com',
  'teads.tv',
  'popads.net',
  'propellerads.com',
  'exoclick.com',
  'mobon.net',
  'dable.io',
  'tenping.kr',
  'adfit.kakao.com',
  'adpopcorn.com',
  'cauly.co.kr',
];

/// 화면에서 숨길 광고 요소. 너무 넓은 선택자(".ad" 등)는 일반 콘텐츠까지
/// 가릴 수 있어 넣지 않는다.
const _hideSelectors = [
  // 일반 광고
  'ins.adsbygoogle',
  '.adsbygoogle',
  '[id^="google_ads_"]',
  '[id^="div-gpt-ad"]',
  '[data-google-query-id]',
  '[data-ad-slot]',
  'amp-ad',
  'amp-embed[type="taboola"]',
  '.ad-banner',
  '.ad_banner',
  '.banner-ad',
  '.adbanner',
  '.adsbox',
  '.ad-container',
  '.ad_container',
  '.advertisement',
  '.sponsored-ad',
  '.taboola',
  '[id^="taboola-"]',
  '.OUTBRAIN',
  '.trc_related_container',
  '.dable_placeholder',
  '[id^="dablewidget"]',
  'iframe[src*="googlesyndication"]',
  'iframe[src*="doubleclick"]',
  // YouTube (데스크톱 / 모바일)
  'ytd-ad-slot-renderer',
  'ytd-in-feed-ad-layout-renderer',
  'ytd-promoted-sparkles-web-renderer',
  'ytd-promoted-video-renderer',
  'ytd-display-ad-renderer',
  'ytd-banner-promo-renderer',
  'ytd-statement-banner-renderer',
  'ytd-merch-shelf-renderer',
  '#player-ads',
  '#masthead-ad',
  'ytm-promoted-sparkles-web-renderer',
  'ytm-companion-ad-renderer',
  'ytm-ad-slot-renderer',
  'ad-slot-renderer',
  '.ytp-ad-overlay-container',
  '.ytp-ad-module .ytp-ad-overlay-slot',
];

bool isAdHost(String host) => adDomains.any((d) => hostMatches(host, d));

/// 페이지에 주입하는 광고 차단 스크립트. 여러 번 실행해도 한 번만 동작한다.
///
/// - 광고 요소를 CSS로 숨기고, 광고 도메인의 iframe/이미지를 지운다.
/// - YouTube 영상 광고는 음소거 후 끝으로 넘기고 "건너뛰기"를 누른다.
final String adBlockScript = '''
(function () {
  if (window.__blromeAdblock) return;
  window.__blromeAdblock = true;
  var css = ${_jsString('${_hideSelectors.join(',')}{display:none!important}')};
  var adHosts = ${_jsArray(adDomains)};

  function addStyle() {
    if (document.getElementById('__blrome_ab')) return;
    var s = document.createElement('style');
    s.id = '__blrome_ab';
    s.textContent = css;
    (document.head || document.documentElement).appendChild(s);
  }
  function isAd(u) {
    try {
      var h = new URL(u, location.href).hostname;
      return adHosts.some(function (d) { return h === d || h.endsWith('.' + d); });
    } catch (e) { return false; }
  }
  function clean(root) {
    if (!root.querySelectorAll) return;
    root.querySelectorAll('iframe[src],img[src]').forEach(function (el) {
      if (isAd(el.src)) el.remove();
    });
  }
  function youtube() {
    if (!/(^|\\.)youtube\\.com\$/.test(location.hostname)) return;
    var v = document.querySelector('.ad-showing video');
    if (v && isFinite(v.duration) && v.duration > 0) {
      v.muted = true;
      v.currentTime = v.duration;
    }
    document.querySelectorAll(
      '.ytp-ad-skip-button,.ytp-ad-skip-button-modern,.ytp-skip-ad-button,.ytp-ad-overlay-close-button'
    ).forEach(function (b) { b.click(); });
  }

  addStyle();
  clean(document);
  new MutationObserver(function (records) {
    addStyle();
    records.forEach(function (r) {
      r.addedNodes.forEach(function (n) {
        if (n.nodeType !== 1) return;
        if ((n.tagName === 'IFRAME' || n.tagName === 'IMG') && n.src && isAd(n.src)) {
          n.remove();
        } else {
          clean(n);
        }
      });
    });
  }).observe(document.documentElement, { childList: true, subtree: true });
  setInterval(youtube, 500);
})();
''';

String _jsString(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

String _jsArray(List<String> items) => '[${items.map(_jsString).join(',')}]';
