library mapper_server;

import 'dart:async';
import 'package:logging/logging.dart';
import 'package:postgresql/pool.dart';
import 'package:postgresql/postgresql.dart';
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
part 'src/exception.dart';

final Logger log = new Logger('Mapper');

class EntityNotifier<E> {
  StreamController<E> _contr_change = new StreamController.broadcast();
  StreamController<E> _contr_update = new StreamController.broadcast();
  StreamController<E> _contr_create = new StreamController.broadcast();
  StreamController<E> _contr_delete = new StreamController.broadcast();

  Stream<E> onChange;
  Stream<E> onUpdate;
  Stream<E> onCreate;
  Stream<E> onDelete;

  EntityNotifier() {
    onChange = _contr_change.stream;
    onUpdate = _contr_update.stream;
    onCreate = _contr_create.stream;
    onDelete = _contr_delete.stream;
  }

  _addUpdate(E o) {
    _contr_update.add(o);
    _contr_change.add(o);
  }

  _addCreate(E o) {
    _contr_create.add(o);
    _contr_change.add(o);
  }

  _addDelete(E o) {
    _contr_delete.add(o);
    _contr_change.add(o);
  }
}

typedef Future<Manager> LoadFunction(String debug);

class Database<A extends Application> {
  static const String _base = '_';
  static Database instance;

  Map<String, LoadFunction> _managers = new Map();

  factory Database() {
    if (instance == null) instance = new Database._();
    return instance;
  }

  Database._();

  add(LoadFunction f, [String namespace = _base]) {
    _managers[namespace] = f;
  }

  Future<Manager<A>> init([String debugId, String namespace = _base]) {
    return _managers[namespace](debugId);
  }
}
