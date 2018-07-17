library mapper_server;

import 'dart:async';
import 'package:logging/logging.dart';
import 'src/postgres.dart' as drv;
import 'client.dart';
export 'client.dart';

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
part 'src/observer.dart';

final Logger _log = new Logger('Mapper');

class EntityContainer<E> {
  final E entity;
  final Map<String, dynamic> diff;
  const EntityContainer(this.entity, this.diff);

  bool isUpdated() => diff != null;
}

class StreamObserver<E> {
  final MEvent scope;
  final Observer observer;

  const StreamObserver(this.scope, this.observer);

  void listen(ObserverFunction<E> f) => observer.addHook(scope, f);
}

class EntityNotifier<E extends Entity<Application>> {
  Observer<E> _observer = new Observer<E>();

  StreamObserver<E> get onCreate =>
      new StreamObserver(MEvent.create, _observer);

  StreamObserver<E> get onUpdate =>
      new StreamObserver(MEvent.update, _observer);

  StreamObserver<E> get onDelete =>
      new StreamObserver(MEvent.delete, _observer);

  StreamObserver<E> get onChange =>
      new StreamObserver(MEvent.change, _observer);

  Future _addUpdate(EntityContainer<E> o) async {
    o.entity.manager = null;
    await _observer.execHooksAsync(MEvent.update, o);
    await _observer.execHooksAsync(MEvent.change, o);
  }

  Future _addCreate(EntityContainer<E> o) async {
    o.entity.manager = null;
    await _observer.execHooksAsync(MEvent.create, o);
    await _observer.execHooksAsync(MEvent.change, o);
  }

  Future _addDelete(EntityContainer<E> o) async {
    o.entity.manager = null;
    await _observer.execHooksAsync(MEvent.delete, o);
    await _observer.execHooksAsync(MEvent.change, o);
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
