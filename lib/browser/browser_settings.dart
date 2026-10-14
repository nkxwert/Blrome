import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../rules/domain_matcher.dart';
import '../storage/storage.dart';

/// 광고 차단, 쿠키, 글자 크기 같은 브라우저 설정.
class BrowserSettings extends ChangeNotifier {
  BrowserSettings(this._storage);

  static const _key = 'browser_settings';

  final BlromeStorage _storage;

  bool _adBlock = true;
  final Set<String> _adBlockExceptions = {};
  bool _thirdPartyCookies = true;
  int _textZoom = 100;

  bool get adBlock => _adBlock;
  Set<String> get adBlockExceptions => Set.unmodifiable(_adBlockExceptions);
  bool get thirdPartyCookies => _thirdPartyCookies;

  /// 웹페이지 글자 크기(%).
  int get textZoom => _textZoom;

  /// [host]에서 광고 차단을 할지. 전체가 꺼져 있거나 예외 사이트면 false.
  bool adBlockEnabledFor(String host) =>
      _adBlock && !_adBlockExceptions.any((d) => hostMatches(host, d));

  void load() {
    final json = _storage.read(_key);
    if (json == null) return;
    final m = jsonDecode(json) as Map<String, dynamic>;
    _adBlock = m['adBlock'] as bool? ?? true;
    _adBlockExceptions
      ..clear()
      ..addAll((m['adBlockExceptions'] as List? ?? const []).cast<String>());
    _thirdPartyCookies = m['thirdPartyCookies'] as bool? ?? true;
    _textZoom = m['textZoom'] as int? ?? 100;
    notifyListeners();
  }

  Future<void> setAdBlock(bool value) => _update(() => _adBlock = value);

  /// [domain]을 광고 차단 예외로 넣거나 뺀다.
  Future<void> setAdBlockException(String domain, bool except) => _update(() {
        except ? _adBlockExceptions.add(domain) : _adBlockExceptions.remove(domain);
      });

  Future<void> setThirdPartyCookies(bool value) =>
      _update(() => _thirdPartyCookies = value);

  Future<void> setTextZoom(int value) => _update(() => _textZoom = value);

  Future<void> _update(void Function() change) async {
    change();
    notifyListeners();
    await _storage.write(
      _key,
      jsonEncode({
        'adBlock': _adBlock,
        'adBlockExceptions': _adBlockExceptions.toList(),
        'thirdPartyCookies': _thirdPartyCookies,
        'textZoom': _textZoom,
      }),
    );
  }
}
