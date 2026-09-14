import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Generic CRUD wrapper around a Hive `Box<Map>`. Each entity repository
/// (WorkTaskRepository, ClientRepository, ...) is a thin typed façade over
/// one of these, keyed by the model's `id`.
class HiveRepository<T> {
  final Box<Map> box;
  final T Function(Map<String, dynamic> map) fromMap;
  final Map<String, dynamic> Function(T item) toMap;
  final String Function(T item) idOf;

  HiveRepository({
    required this.box,
    required this.fromMap,
    required this.toMap,
    required this.idOf,
  });

  List<T> getAll() {
    return box.values.map((m) => fromMap(Map<String, dynamic>.from(m))).toList();
  }

  Future<void> put(T item) => box.put(idOf(item), toMap(item));

  Future<void> delete(String id) => box.delete(id);

  ValueListenable<Box<Map>> listenable() => box.listenable();
}
