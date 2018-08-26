part of mapper_server;

typedef ObserverFunction<E extends Entity> = FutureOr<dynamic> Function(
    EntityContainer<E>);

enum MEvent { update, create, delete, change }

class Observer<E extends Entity> {
  final Map<MEvent, List<ObserverFunction<E>>> _hook =
      <MEvent, List<ObserverFunction<E>>>{};

  Observer();

  void addHook(MEvent scope, ObserverFunction<E> func) {
    if (_hook[scope] == null) _hook[scope] = [];
    _hook[scope].add(func);
  }

  Future execHooksAsync(MEvent scope, EntityContainer<E> object) async {
    if (!_hook.containsKey(scope)) return;
    for (var f in _hook[scope]) await f(object);
  }
}
