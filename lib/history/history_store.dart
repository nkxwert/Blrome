import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../storage/storage.dart';

class HistoryEntry {
  HistoryEntry({required this.url, required this.title, required this.time});

  final String url;
  String title;
  DateTime time;

  Map<String, dynamic> toJson() =>
      {'url': url, 'title': title, 't': time.millisecondsSinceEpoch};

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        url: json['url'] as String,
        title: json['title'] as String? ?? '',
        time: DateTime.fromMillisecondsSinceEpoch(json['t'] as int),
      );
}

/// 방문 기록. 최신순으로 보관한다.
class HistoryStore extends ChangeNotifier {
  HistoryStore(this._storage, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static const _key = 'history';
  static const keepDays = 30;
  static const maxEntries = 3000;

  /// 같은 주소를 이 시간 안에 다시 열면 새 항목을 만들지 않고 갱신한다.
  static const mergeWindow = Duration(minutes: 30);

  final BlromeStorage _storage;
  final DateTime Function() _clock;
  final List<HistoryEntry> _entries = [];

  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  void load() {
    _entries.clear();
    final json = _storage.read(_key);
    if (json != null) {
      for (final e in jsonDecode(json) as List) {
        _entries.add(HistoryEntry.fromJson(e as Map<String, dynamic>));
      }
    }
    _prune();
    notifyListeners();
  }

  /// 페이지 방문을 기록한다. http(s)가 아니면 무시.
  Future<void> add(String url, String title) async {
    final scheme = Uri.tryParse(url)?.scheme;
    if (scheme != 'http' && scheme != 'https') return;
    final now = _clock();
    final i = _entries.indexWhere((e) => e.url == url);
    if (i >= 0 && now.difference(_entries[i].time) < mergeWindow) {
      final e = _entries.removeAt(i);
      if (title.isNotEmpty) e.title = title;
      e.time = now;
      _entries.insert(0, e);
    } else {
      _entries.insert(0, HistoryEntry(url: url, title: title, time: now));
    }
    _prune();
    notifyListeners();
    await _save();
  }

  Future<void> remove(HistoryEntry entry) async {
    _entries.remove(entry);
    notifyListeners();
    await _save();
  }

  Future<void> clear() async {
    _entries.clear();
    notifyListeners();
    await _save();
  }

  void _prune() {
    final cutoff = _clock().subtract(const Duration(days: keepDays));
    _entries.removeWhere((e) => e.time.isBefore(cutoff));
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
  }

  Future<void> _save() => _storage.write(
      _key, jsonEncode(_entries.map((e) => e.toJson()).toList()));
}
