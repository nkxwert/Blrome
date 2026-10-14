import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'rules/domain_matcher.dart';
import 'rules/rule_engine.dart';
import 'rules/site_rule.dart';
import 'storage/storage.dart';

/// 규칙, 날짜별 사용량, 오늘 해제 목록을 관리한다.
///
/// 사용량은 `usage["2026-10-14"]["youtube.com"] = 초` 형태로 날짜별로 저장하므로
/// 자정이 지나면 새 날짜 키로 넘어가며 자연스럽게 0부터 다시 센다.
class BlromeController extends ChangeNotifier {
  BlromeController(this._storage, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static const _rulesKey = 'rules';
  static const _usageKey = 'usage';
  static const _unlocksKey = 'unlocks';

  /// 이보다 오래된 사용 기록은 지운다.
  static const keepDays = 30;

  final BlromeStorage _storage;
  final DateTime Function() _clock;

  final Map<String, SiteRule> _rules = {};
  final Map<String, Map<String, int>> _usage = {};
  final Map<String, Set<String>> _unlocks = {};

  /// 규칙 목록 (도메인 이름순).
  List<SiteRule> get rules =>
      _rules.values.toList()..sort((a, b) => a.domain.compareTo(b.domain));

  /// 오늘 날짜 키 (기기 현지 시간 기준, "yyyy-MM-dd").
  String get todayKey => dateKey(_clock());

  static String dateKey(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  void load() {
    _rules.clear();
    _usage.clear();
    _unlocks.clear();

    final rulesJson = _storage.read(_rulesKey);
    if (rulesJson != null) {
      for (final r in jsonDecode(rulesJson) as List) {
        final rule = SiteRule.fromJson(r as Map<String, dynamic>);
        _rules[rule.domain] = rule;
      }
    }

    final usageJson = _storage.read(_usageKey);
    if (usageJson != null) {
      (jsonDecode(usageJson) as Map<String, dynamic>).forEach((day, m) {
        _usage[day] = (m as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int));
      });
    }

    final unlocksJson = _storage.read(_unlocksKey);
    if (unlocksJson != null) {
      (jsonDecode(unlocksJson) as Map<String, dynamic>).forEach((day, l) {
        _unlocks[day] = (l as List).cast<String>().toSet();
      });
    }

    _prune();
    notifyListeners();
  }

  void _prune() {
    final cutoff = dateKey(_clock().subtract(const Duration(days: keepDays)));
    _usage.removeWhere((day, _) => day.compareTo(cutoff) < 0);
    final today = todayKey;
    _unlocks.removeWhere((day, _) => day != today);
  }

  // ---- 판단 ----

  SiteRule? ruleFor(String host) => findRule(host, _rules.values);

  int usedSecondsToday(String domain) => _usage[todayKey]?[domain] ?? 0;

  bool isUnlockedToday(String domain) =>
      _unlocks[todayKey]?.contains(domain) ?? false;

  SiteDecision decide(String host) {
    final rule = ruleFor(host);
    return evaluate(
      rule,
      usedSecondsToday: rule == null ? 0 : usedSecondsToday(rule.domain),
      unlockedToday: rule != null && isUnlockedToday(rule.domain),
    );
  }

  SiteDecision decideUrl(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isEmpty) return const SiteDecision.allowed();
    return decide(host);
  }

  // ---- 변경 ----

  /// 오늘 [domain] 사용량에 [seconds]초를 더한다. 저장은 [flush]에서 한다.
  void addUsage(String domain, int seconds) {
    final day = _usage.putIfAbsent(todayKey, () => {});
    day[domain] = (day[domain] ?? 0) + seconds;
    notifyListeners();
  }

  Future<void> upsertRule(SiteRule rule, {String? replacing}) async {
    if (replacing != null && replacing != rule.domain) _rules.remove(replacing);
    _rules[rule.domain] = rule;
    notifyListeners();
    await _saveRules();
  }

  Future<void> removeRule(String domain) async {
    _rules.remove(domain);
    notifyListeners();
    await _saveRules();
  }

  /// 오늘 하루 [domain] 차단을 푼다. 자정이 지나면 다시 적용된다.
  Future<void> unlockToday(String domain) async {
    _unlocks.putIfAbsent(todayKey, () => {}).add(domain);
    notifyListeners();
    await _saveUnlocks();
  }

  /// 메모리의 사용량과 해제 목록을 저장소에 쓴다.
  Future<void> flush() async {
    _prune();
    await _storage.write(_usageKey, jsonEncode(_usage));
    await _saveUnlocks();
  }

  Future<void> _saveRules() => _storage.write(
      _rulesKey, jsonEncode(_rules.values.map((r) => r.toJson()).toList()));

  Future<void> _saveUnlocks() => _storage.write(
      _unlocksKey, jsonEncode(_unlocks.map((k, v) => MapEntry(k, v.toList()))));
}
