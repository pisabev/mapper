part of mapper_server;

typedef ObserverFunction<E> = FutureOr Function(EntityContainer<E>);

enum MEvent { update, create, delete, change }

class Observer<E> {
  Map<MEvent, List<ObserverFunction>> _hook =
  new Map<MEvent, List<ObserverFunction>>();

  Observer();

  void addHook(MEvent scope, ObserverFunction func) {
    if (_hook[scope] == null) _hook[scope] = new List();
    _hook[scope].add(func);
  }

  Future execHooksAsync(
      MEvent scope, EntityContainer<E> object) async {
    if (!_hook.containsKey(scope)) return;
    for (var f in _hook[scope]) await f(object);
  }
}
