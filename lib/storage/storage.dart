import 'package:hive_flutter/hive_flutter.dart';

/// 문자열 키-값 저장소. 테스트에서는 [MemoryStorage]로 바꿔 끼운다.
abstract class BlromeStorage {
  String? read(String key);
  Future<void> write(String key, String value);
}

class HiveStorage implements BlromeStorage {
  HiveStorage._(this._box);

  final Box<String> _box;

  static Future<HiveStorage> open() async {
    await Hive.initFlutter();
    return HiveStorage._(await Hive.openBox<String>('blrome'));
  }

  @override
  String? read(String key) => _box.get(key);

  @override
  Future<void> write(String key, String value) => _box.put(key, value);
}

class MemoryStorage implements BlromeStorage {
  final Map<String, String> data = {};

  @override
  String? read(String key) => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}
