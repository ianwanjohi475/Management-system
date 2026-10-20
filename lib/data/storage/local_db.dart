import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../models/models.dart';

/// Opens Hive once for the whole app. Each record is stored as a JSON string,
/// so a schema change or a single corrupt record can never brick the database.
abstract final class LocalDb {
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    try {
      await Hive.initFlutter('shamba');
      _ready = true;
    } catch (e) {
      throw StorageException('Could not open phone storage.', cause: e);
    }
  }

  /// Uses a plain directory instead of the app folder (for tests).
  @visibleForTesting
  static void initAt(String path) {
    Hive.init(path);
    _ready = true;
  }

  /// Untyped box for small settings values.
  static Future<Box> openRaw(String name) async {
    try {
      return await Hive.openBox(name);
    } catch (e) {
      try {
        await Hive.deleteBoxFromDisk(name);
        return await Hive.openBox(name);
      } catch (e2) {
        throw StorageException('App settings could not be opened.', cause: e2);
      }
    }
  }

  /// Opens a box; if it is corrupt, the damaged copy is wiped and a fresh one opened
  /// so the app still starts (the farmer can restore from a backup).
  static Future<Box<String>> open(String name) async {
    try {
      return await Hive.openBox<String>(name);
    } catch (e, st) {
      debugPrint('Box "$name" failed to open: $e\n$st');
      try {
        await Hive.deleteBoxFromDisk(name);
        return await Hive.openBox<String>(name);
      } catch (e2) {
        throw StorageException('Your farm data could not be opened.', cause: e2);
      }
    }
  }
}

/// A typed, in-memory mirror of one record type. All types share one Hive box
/// (keys are `prefix/id`), so a farm opens as a single database.
class Collection<T extends Entity> {
  Collection(this.box, this.prefix, this._fromJson) {
    _load();
  }

  final Box<String> box;
  final String prefix;
  final T Function(Map) _fromJson;
  final Map<String, T> _items = {};

  String _key(String id) => '$prefix/$id';

  /// How many records were skipped because they could not be read.
  int corrupt = 0;

  void _load() {
    _items.clear();
    corrupt = 0;
    for (final key in box.keys) {
      if (key is! String || !key.startsWith('$prefix/')) continue;
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) throw const FormatException('not an object');
        final item = _fromJson(decoded);
        _items[item.id] = item;
      } catch (e) {
        corrupt++;
        debugPrint('Skipping unreadable record $key: $e');
      }
    }
  }

  List<T> get all => _items.values.toList(growable: false);
  int get length => _items.length;
  T? byId(String? id) => id == null ? null : _items[id];
  bool contains(String id) => _items.containsKey(id);

  Future<void> put(T item) async {
    try {
      await box.put(_key(item.id), jsonEncode(item.toJson()));
      _items[item.id] = item;
    } catch (e) {
      throw StorageException('Could not save. Check your phone storage and try again.', cause: e);
    }
  }

  Future<void> putAll(Iterable<T> items) async {
    try {
      await box.putAll({for (final i in items) _key(i.id): jsonEncode(i.toJson())});
      for (final i in items) {
        _items[i.id] = i;
      }
    } catch (e) {
      throw StorageException('Could not save. Check your phone storage and try again.', cause: e);
    }
  }

  Future<void> remove(String id) async {
    try {
      await box.delete(_key(id));
      _items.remove(id);
    } catch (e) {
      throw StorageException('Could not delete. Please try again.', cause: e);
    }
  }

  Future<void> removeWhere(bool Function(T) test) async {
    final ids = _items.values.where(test).map((e) => e.id).toList();
    if (ids.isEmpty) return;
    try {
      await box.deleteAll(ids.map(_key));
      for (final id in ids) {
        _items.remove(id);
      }
    } catch (e) {
      throw StorageException('Could not delete. Please try again.', cause: e);
    }
  }

  Future<void> clear() async {
    await box.deleteAll(_items.keys.map(_key).toList());
    _items.clear();
  }

  List<Map<String, dynamic>> export() => _items.values.map((e) => e.toJson()).toList();

  /// Replaces everything with [rows]; bad rows are skipped and counted.
  Future<int> importRows(List rows) async {
    final parsed = <T>[];
    var skipped = 0;
    for (final r in rows) {
      try {
        if (r is! Map) throw const FormatException();
        parsed.add(_fromJson(r));
      } catch (_) {
        skipped++;
      }
    }
    await clear();
    await putAll(parsed);
    return skipped;
  }
}
