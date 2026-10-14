package com.blrome.blrome

import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "blrome/adblock")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Dart의 WebViewController에 해당하는 네이티브 WebView에 광고 차단을 건다.
                    "attach" -> {
                        val id = call.argument<Number>("id")?.toLong()
                        val plugin = flutterEngine.plugins.get(WebViewFlutterPlugin::class.java)
                            as? WebViewFlutterPlugin
                        val webView = id?.let {
                            plugin?.instanceManager?.getInstance<Any>(it) as? WebView
                        }
                        result.success(webView != null && AdBlocker.attach(this, webView))
                    }
                    "configure" -> {
                        AdBlocker.configure(
                            call.argument<Boolean>("enabled") ?: true,
                            call.argument<List<String>>("exceptions") ?: emptyList(),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
