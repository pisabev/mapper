library mapper_server;

import 'dart:async';
import 'package:logging/logging.dart';
import 'package:postgresql/pool.dart' as drv_pool;
import 'package:postgresql/postgresql.dart' as drv;
import 'package:meta/meta.dart';
import 'client.dart';

part 'src/application.dart';
part 'src/builder.dart';
part 'src/mapper.dart';
part 'src/connection.dart';
part 'src/manager.dart';
part 'src/unit.dart';
part 'src/entity.dart';
part 'src/cache.dart';
part 'src/pool.dart';
part 'src/exception.dart';

final Logger _log = new Logger('Mapper');

class EntityContainer<E> {
  final E entity;
  final Map<String, dynamic> diff;
  const EntityContainer(this.entity, this.diff);

  bool isUpdated() => diff != null;
}

class EntityNotifier<E> {
  StreamController<EntityContainer<E>> _contr_change =
      new StreamController.broadcast();
  StreamController<EntityContainer<E>> _contr_update =
      new StreamController.broadcast();
  StreamController<EntityContainer<E>> _contr_create =
      new StreamController.broadcast();
  StreamController<EntityContainer<E>> _contr_delete =
      new StreamController.broadcast();

  Stream<EntityContainer<E>> onChange;
  Stream<EntityContainer<E>> onUpdate;
  Stream<EntityContainer<E>> onCreate;
  Stream<EntityContainer<E>> onDelete;

  EntityNotifier() {
    onChange = _contr_change.stream;
    onUpdate = _contr_update.stream;
    onCreate = _contr_create.stream;
    onDelete = _contr_delete.stream;
  }

  _addUpdate(EntityContainer<E> o) {
    _contr_update.add(o);
    _contr_change.add(o);
  }

  _addCreate(EntityContainer<E> o) {
    _contr_create.add(o);
    _contr_change.add(o);
  }

  _addDelete(EntityContainer<E> o) {
    _contr_delete.add(o);
    _contr_change.add(o);
  }
}

typedef Future<Manager> LoadFunction();

class Database<A extends Application> {
  static const String _base = '_';
  static Database instance;

  Map<String, LoadFunction> _managers = new Map();

  factory Database() {
    if (instance == null) instance = new Database._();
    return instance;
  }

  Database._();

  void add(LoadFunction f, [String namespace = _base]) {
    _managers[namespace] = f;
  }

  Future<Manager<A>> init([String namespace = _base]) {
    return _managers[namespace]();
  }
}
