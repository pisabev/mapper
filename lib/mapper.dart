library mapper_server;

import 'dart:async';
//import 'package:logging/logging.dart';
import 'src/postgres.dart' as drv;
import 'client.dart';
export 'client.dart';

part 'src/application.dart';
part 'src/builder.dart';
part 'src/mapper.dart';
part 'src/manager.dart';
part 'src/unit.dart';
part 'src/entity.dart';
part 'src/cache.dart';
part 'src/pool.dart';
part 'src/exception.dart';
part 'src/observer.dart';

class EntityContainer<E extends Entity> {
  final E entity;
  final Map<String, dynamic> diff;
  const EntityContainer(this.entity, this.diff);

  bool isUpdated() => diff != null;
}

class StreamObserver<E extends Entity> {
  final MEvent scope;
  final Observer<E> observer;

  const StreamObserver(this.scope, this.observer);

  void listen(ObserverFunction<E> f) => observer.addHook(scope, f);
}

class EntityNotifier<E extends Entity> {
  final Observer<E> _observer = new Observer<E>();

  StreamObserver<E> get onCreate =>
      new StreamObserver<E>(MEvent.create, _observer);

  StreamObserver<E> get onUpdate =>
      new StreamObserver<E>(MEvent.update, _observer);

  StreamObserver<E> get onDelete =>
      new StreamObserver<E>(MEvent.delete, _observer);

  StreamObserver<E> get onChange =>
      new StreamObserver<E>(MEvent.change, _observer);

  Future _addUpdate(EntityContainer<E> o) async {
    await _observer.execHooksAsync(MEvent.update, o);
    await _observer.execHooksAsync(MEvent.change, o);
  }

  Future _addCreate(EntityContainer<E> o) async {
    await _observer.execHooksAsync(MEvent.create, o);
    await _observer.execHooksAsync(MEvent.change, o);
  }

  Future _addDelete(EntityContainer<E> o) async {
    await _observer.execHooksAsync(MEvent.delete, o);
    await _observer.execHooksAsync(MEvent.change, o);
  }
}

class Database {
  static const String _base = '_';
  static Database instance;

  final Map<String, Pool> _pools = {};

  factory Database() => instance ??= new Database._();

  Database._();

  void registerPool(Pool pool, [String namespace = _base]) {
    _pools[namespace] = pool;
  }

  Future<Manager<A>> init<A extends Application>(A app,
      [String namespace = _base]) async {
    final m = new Manager<A>(_pools[namespace], app);
    await m.init();
    return m;
  }
}
