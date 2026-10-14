import 'package:blrome/history/history_store.dart';
import 'package:blrome/storage/storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryStorage storage;
  late DateTime now;
  late HistoryStore h;

  setUp(() {
    storage = MemoryStorage();
    now = DateTime(2026, 10, 14, 12);
    h = HistoryStore(storage, clock: () => now)..load();
  });

  test('최신순으로 쌓고 http(s)만 기록한다', () async {
    await h.add('https://a.com/', 'A');
    now = now.add(const Duration(minutes: 1));
    await h.add('https://b.com/', 'B');
    await h.add('about:blank', '');
    expect(h.entries.map((e) => e.url), ['https://b.com/', 'https://a.com/']);
  });

  test('같은 주소를 곧 다시 열면 합치고, 오래 지나면 새로 쌓는다', () async {
    await h.add('https://a.com/', 'A');
    now = now.add(const Duration(minutes: 5));
    await h.add('https://a.com/', 'A2');
    expect(h.entries.length, 1);
    expect(h.entries.first.title, 'A2');

    now = now.add(const Duration(hours: 1));
    await h.add('https://a.com/', 'A3');
    expect(h.entries.length, 2);
  });

  test('저장 후 다시 불러오고, 30일 지난 기록은 지운다', () async {
    await h.add('https://a.com/', 'A');
    expect((HistoryStore(storage, clock: () => now)..load()).entries.length, 1);

    now = now.add(const Duration(days: 31));
    expect((HistoryStore(storage, clock: () => now)..load()).entries, isEmpty);
  });

  test('삭제', () async {
    await h.add('https://a.com/', 'A');
    await h.add('https://b.com/', 'B');
    await h.remove(h.entries.first);
    expect(h.entries.length, 1);
    await h.clear();
    expect(h.entries, isEmpty);
  });
}
