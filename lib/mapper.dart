library mapper_server;

import 'dart:async';
import 'dart:convert';

import 'client.dart';
import 'src/postgres.dart' as drv;

export 'client.dart';

part 'src/application.dart';

part 'src/builder.dart';

part 'src/cache.dart';

part 'src/entity.dart';

part 'src/exception.dart';

part 'src/manager.dart';

part 'src/mapper.dart';

part 'src/mapper_base.dart';

part 'src/mapper_view.dart';

part 'src/pool.dart';

part 'src/unit.dart';

class EntityContainer<E extends Entity> {
  final E entity;
  final Map<String, dynamic>? diff;
  final bool deleted;

  const EntityContainer(this.entity, {this.diff, this.deleted = false});

  bool get isUpdated => diff != null;

  bool get isDeleted => deleted;

  bool get isInserted => !isUpdated && !isDeleted;
}

class EntityNotifier<E extends Entity> {
  final StreamController<EntityContainer<E>> _contr_change =
      new StreamController.broadcast();
  final StreamController<EntityContainer<E>> _contr_update =
      new StreamController.broadcast();
  final StreamController<EntityContainer<E>> _contr_create =
      new StreamController.broadcast();
  final StreamController<EntityContainer<E>> _contr_delete =
      new StreamController.broadcast();

  late Stream<EntityContainer<E>> onChange;
  late Stream<EntityContainer<E>> onUpdate;
  late Stream<EntityContainer<E>> onCreate;
  late Stream<EntityContainer<E>> onDelete;

  EntityNotifier() {
    onChange = _contr_change.stream;
    onUpdate = _contr_update.stream;
    onCreate = _contr_create.stream;
    onDelete = _contr_delete.stream;
  }

  void _addUpdate(EntityContainer<E> o) {
    _contr_update.add(o);
    _contr_change.add(o);
  }

  void _addCreate(EntityContainer<E> o) {
    _contr_create.add(o);
    _contr_change.add(o);
  }

  void _addDelete(EntityContainer<E> o) {
    _contr_delete.add(o);
    _contr_change.add(o);
  }
}

class Database {
  static const String _base = '_';
  static Database? _instance;

  final Map<String, Pool> pools = {};

  factory Database() => _instance ??= new Database._();

  Database._();

  void registerPool(Pool pool, [String namespace = _base]) {
    pools[namespace] = pool;
  }

  Future<Manager> init([String namespace = _base]) async {
    final m = new Manager(pools[namespace]!);
    await m.init();
    return m;
  }
}
