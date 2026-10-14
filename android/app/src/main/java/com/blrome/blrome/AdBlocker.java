package com.blrome.blrome;

import android.content.Context;
import android.os.Build;
import android.util.Log;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;
import io.flutter.FlutterInjector;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Collection;
import java.util.Collections;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

/** 광고·추적 도메인으로 가는 요청을 막는다. 목록은 assets/adblock/hosts.txt. */
final class AdBlocker {
  private static final String TAG = "BlromeAdBlocker";
  private static final String HOSTS_ASSET = "assets/adblock/hosts.txt";

  private static volatile Set<String> hosts = Collections.emptySet();
  private static volatile boolean enabled = true;
  private static volatile Set<String> exceptions = Collections.emptySet();
  private static boolean loadStarted;

  private AdBlocker() {}

  /** 도메인 목록을 백그라운드에서 한 번 읽는다. 읽는 동안에는 아무것도 막지 않는다. */
  static synchronized void ensureLoaded(Context context) {
    if (loadStarted) return;
    loadStarted = true;
    final Context app = context.getApplicationContext();
    new Thread(
            () -> {
              final HashSet<String> set = new HashSet<>(100_000);
              final String key =
                  FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(HOSTS_ASSET);
              try (BufferedReader reader =
                  new BufferedReader(
                      new InputStreamReader(app.getAssets().open(key), StandardCharsets.UTF_8))) {
                String line;
                while ((line = reader.readLine()) != null) {
                  line = line.trim();
                  if (!line.isEmpty() && line.charAt(0) != '#') set.add(line);
                }
              } catch (IOException e) {
                Log.w(TAG, "광고 도메인 목록을 읽지 못했습니다", e);
              }
              hosts = set;
              Log.i(TAG, "광고 도메인 " + set.size() + "개 로드");
            },
            "blrome-adblock-load")
        .start();
  }

  /** Dart 설정(전체 켜기/끄기, 예외 사이트)을 반영한다. */
  static void configure(boolean enabled, Collection<String> exceptions) {
    AdBlocker.enabled = enabled;
    AdBlocker.exceptions = new HashSet<>(exceptions);
  }

  /** [pageHost] 페이지에서 광고 차단을 할지. */
  static boolean isEnabledFor(String pageHost) {
    if (!enabled) return false;
    if (pageHost == null) return true;
    final String host = pageHost.toLowerCase(Locale.ROOT);
    for (String domain : exceptions) {
      if (host.equals(domain) || host.endsWith("." + domain)) return false;
    }
    return true;
  }

  /** [host] 또는 그 상위 도메인이 목록에 있으면 true. */
  static boolean isAdHost(String host) {
    if (host == null || host.isEmpty()) return false;
    final Set<String> set = hosts;
    String h = host.toLowerCase(Locale.ROOT);
    while (true) {
      if (set.contains(h)) return true;
      final int dot = h.indexOf('.');
      if (dot < 0) return false;
      h = h.substring(dot + 1);
    }
  }

  /** [webView]의 WebViewClient를 광고 차단 래퍼로 감싼다. 성공하면 true. */
  static boolean attach(Context context, WebView webView) {
    ensureLoaded(context);
    final WebViewClient current;
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      current = webView.getWebViewClient();
    } else if (WebViewFeature.isFeatureSupported(WebViewFeature.GET_WEB_VIEW_CLIENT)) {
      current = WebViewCompat.getWebViewClient(webView);
    } else {
      return false;
    }
    if (current instanceof BlockingWebViewClient) return true;
    webView.setWebViewClient(new BlockingWebViewClient(current));
    return true;
  }
}
