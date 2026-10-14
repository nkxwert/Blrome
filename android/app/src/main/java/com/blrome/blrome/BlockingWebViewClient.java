package com.blrome.blrome;

import android.graphics.Bitmap;
import android.net.Uri;
import android.net.http.SslError;
import android.os.Message;
import android.view.KeyEvent;
import android.webkit.ClientCertRequest;
import android.webkit.HttpAuthHandler;
import android.webkit.RenderProcessGoneDetail;
import android.webkit.SafeBrowsingResponse;
import android.webkit.SslErrorHandler;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import androidx.annotation.RequiresApi;
import java.io.ByteArrayInputStream;

/**
 * webview_flutter가 설치한 WebViewClient를 감싸서, 광고 도메인으로 가는 하위 요청(스크립트·이미지·
 * iframe 등)에는 빈 응답을 돌려준다. 나머지 콜백은 모두 원래 클라이언트에 그대로 넘긴다.
 *
 * <p>메인 프레임 요청은 막지 않는다 (페이지 이동 차단은 Dart 쪽에서 처리).
 */
final class BlockingWebViewClient extends WebViewClient {
  private final WebViewClient delegate;

  /** 지금 열린 페이지의 호스트. 사이트별 예외 판단에 쓴다. */
  private volatile String pageHost;

  BlockingWebViewClient(WebViewClient delegate) {
    this.delegate = delegate != null ? delegate : new WebViewClient();
  }

  @Override
  public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
    final Uri url = request.getUrl();
    if (request.isForMainFrame()) {
      pageHost = url.getHost();
    } else if (AdBlocker.isEnabledFor(pageHost) && AdBlocker.isAdHost(url.getHost())) {
      return new WebResourceResponse("text/plain", "utf-8", new ByteArrayInputStream(new byte[0]));
    }
    return delegate.shouldInterceptRequest(view, request);
  }

  @Override
  public void onPageStarted(WebView view, String url, Bitmap favicon) {
    if (url != null) pageHost = Uri.parse(url).getHost();
    delegate.onPageStarted(view, url, favicon);
  }

  // ---- 이하 원래 클라이언트로 전달 ----

  @Override
  public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
    return delegate.shouldOverrideUrlLoading(view, request);
  }

  @Override
  public void onPageFinished(WebView view, String url) {
    delegate.onPageFinished(view, url);
  }

  @Override
  public void onLoadResource(WebView view, String url) {
    delegate.onLoadResource(view, url);
  }

  @Override
  public void onPageCommitVisible(WebView view, String url) {
    delegate.onPageCommitVisible(view, url);
  }

  @Override
  public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
    delegate.onReceivedError(view, request, error);
  }

  @Override
  public void onReceivedHttpError(
      WebView view, WebResourceRequest request, WebResourceResponse errorResponse) {
    delegate.onReceivedHttpError(view, request, errorResponse);
  }

  @Override
  public void onFormResubmission(WebView view, Message dontResend, Message resend) {
    delegate.onFormResubmission(view, dontResend, resend);
  }

  @Override
  public void doUpdateVisitedHistory(WebView view, String url, boolean isReload) {
    delegate.doUpdateVisitedHistory(view, url, isReload);
  }

  @Override
  public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {
    delegate.onReceivedSslError(view, handler, error);
  }

  @Override
  public void onReceivedClientCertRequest(WebView view, ClientCertRequest request) {
    delegate.onReceivedClientCertRequest(view, request);
  }

  @Override
  public void onReceivedHttpAuthRequest(
      WebView view, HttpAuthHandler handler, String host, String realm) {
    delegate.onReceivedHttpAuthRequest(view, handler, host, realm);
  }

  @Override
  public boolean shouldOverrideKeyEvent(WebView view, KeyEvent event) {
    return delegate.shouldOverrideKeyEvent(view, event);
  }

  @Override
  public void onUnhandledKeyEvent(WebView view, KeyEvent event) {
    delegate.onUnhandledKeyEvent(view, event);
  }

  @Override
  public void onScaleChanged(WebView view, float oldScale, float newScale) {
    delegate.onScaleChanged(view, oldScale, newScale);
  }

  @Override
  public void onReceivedLoginRequest(WebView view, String realm, String account, String args) {
    delegate.onReceivedLoginRequest(view, realm, account, args);
  }

  @RequiresApi(26)
  @Override
  public boolean onRenderProcessGone(WebView view, RenderProcessGoneDetail detail) {
    return delegate.onRenderProcessGone(view, detail);
  }

  @RequiresApi(27)
  @Override
  public void onSafeBrowsingHit(
      WebView view, WebResourceRequest request, int threatType, SafeBrowsingResponse callback) {
    delegate.onSafeBrowsingHit(view, request, threatType, callback);
  }
}
