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
/// 사용 시간 표를 위해 10분 단위 칸(`slots[날짜][0..143][사이트] = 초`)도 함께 쌓는다.
class BlromeController extends ChangeNotifier {
  BlromeController(this._storage, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static const _rulesKey = 'rules';
  static const _usageKey = 'usage';
  static const _unlocksKey = 'unlocks';
  static const _slotsKey = 'slots';

  /// 사용 시간 표의 한 칸 길이(분).
  static const slotMinutes = 10;
  static const slotsPerDay = 24 * 60 ~/ slotMinutes;

  /// 이보다 오래된 사용 기록은 지운다.
  static const keepDays = 30;

  final BlromeStorage _storage;
  final DateTime Function() _clock;

  final Map<String, SiteRule> _rules = {};
  final Map<String, Map<String, int>> _usage = {};
  final Map<String, Set<String>> _unlocks = {};
  final Map<String, Map<int, Map<String, int>>> _slots = {};

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
    _slots.clear();

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

    final slotsJson = _storage.read(_slotsKey);
    if (slotsJson != null) {
      (jsonDecode(slotsJson) as Map<String, dynamic>).forEach((day, m) {
        _slots[day] = (m as Map<String, dynamic>).map((slot, sites) => MapEntry(
            int.parse(slot),
            (sites as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int))));
      });
    }

    _prune();
    notifyListeners();
  }

  void _prune() {
    final cutoff = dateKey(_clock().subtract(const Duration(days: keepDays)));
    _usage.removeWhere((day, _) => day.compareTo(cutoff) < 0);
    _slots.removeWhere((day, _) => day.compareTo(cutoff) < 0);
    final today = todayKey;
    _unlocks.removeWhere((day, _) => day != today);
  }

  // ---- 판단 ----

  SiteRule? ruleFor(String host) => findRule(host, _rules.values);

  /// 사용 시간을 쌓을 사이트 이름. 규칙이 있으면 규칙 도메인, 없으면 www를 뗀 호스트.
  String siteKeyFor(String host) {
    final rule = ruleFor(host);
    if (rule != null) return rule.domain;
    final h = host.toLowerCase();
    return h.startsWith('www.') ? h.substring(4) : h;
  }

  /// 기록이 있는 날짜들 (오래된 순).
  List<String> get usageDays => _usage.keys.toList()..sort();

  /// [day]의 사이트별 사용량(초).
  Map<String, int> usageForDay(String day) => Map.unmodifiable(_usage[day] ?? {});

  /// [day]의 10분 칸별 사이트 사용량(초).
  Map<int, Map<String, int>> slotsForDay(String day) => _slots[day] ?? const {};

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

  /// 지금 시각에 [site] 사용량 [seconds]초를 더한다. 저장은 [flush]에서 한다.
  void addUsage(String site, int seconds) {
    final now = _clock();
    final key = dateKey(now);
    final day = _usage.putIfAbsent(key, () => {});
    day[site] = (day[site] ?? 0) + seconds;
    final slot = (now.hour * 60 + now.minute) ~/ slotMinutes;
    final cell = _slots.putIfAbsent(key, () => {}).putIfAbsent(slot, () => {});
    cell[site] = (cell[site] ?? 0) + seconds;
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
    await _storage.write(
        _slotsKey,
        jsonEncode(_slots.map((day, m) =>
            MapEntry(day, m.map((slot, v) => MapEntry('$slot', v))))));
    await _saveUnlocks();
  }

  Future<void> _saveRules() => _storage.write(
      _rulesKey, jsonEncode(_rules.values.map((r) => r.toJson()).toList()));

  Future<void> _saveUnlocks() => _storage.write(
      _unlocksKey, jsonEncode(_unlocks.map((k, v) => MapEntry(k, v.toList()))));
}
