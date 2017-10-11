part of mapper_server;

class Unit<A extends Application> {
  Manager _manager;

  List<Entity> _dirty;

  List<Entity> _new;

  List<Entity> _delete;

  Map<Entity, Function> _notifyInsert;

  Map<Entity, Function> _notifyUpdate;

  Map<Entity, Function> _notifyDelete;

  bool _started = false;

  Unit(Manager manager) {
    _manager = manager;
    _resetEntities();
    _resetNotifiers();
  }

  _resetEntities() {
    _dirty = new List<Entity<A>>();
    _new = new List<Entity<A>>();
    _delete = new List<Entity<A>>();
  }

  _resetNotifiers() {
    _notifyInsert = new Map();
    _notifyUpdate = new Map();
    _notifyDelete = new Map();
  }

  void addDirty(Entity<A> object) =>
      (!_new.contains(object) && !_dirty.contains(object))
          ? _dirty.add(object)
          : null;

  void addNew(Entity<A> object) =>
      (!_new.contains(object)) ? _new.add(object) : null;

  void addDelete(Entity<A> object) {
    (!_delete.contains(object)) ? _delete.add(object) : null;
    if(_new.contains(object)) _new.remove(object);
  }

  void _addNotifyUpdate(Entity<A> object, Function f) =>
      (!_notifyInsert.containsKey(object) && !_notifyUpdate.containsKey(object))
          ? _notifyUpdate[object] = f
          : null;

  void _addNotifyInsert(Entity<A> object, Function f) =>
      (!_notifyInsert.containsKey(object)) ? _notifyInsert[object] = f : null;

  void _addNotifyDelete(Entity<A> object, Function f) {
    (!_notifyDelete.containsKey(object)) ? _notifyDelete[object] = f : null;
    if(_notifyInsert.containsKey(object)) _notifyInsert.remove(object);
  }

  Future _doUpdates() => Future.wait(_dirty.map((o) async {
        var m = _manager._mapper(o);
        await m.update(o);
        if (m.notifier != null) {
          var diffm = m._readDiff(o);
          if (diffm.isNotEmpty)
            _addNotifyUpdate(o, () => m.notifier._addUpdate(new EntityContainer(o, diffm)));
        }
      }));

  Future _doInserts() => Future.wait(_new.map((o) async {
        var m = _manager._mapper(o);
        await m.insert(o);
        if (m.notifier != null)
          _addNotifyInsert(o, () => m.notifier._addCreate(new EntityContainer(o, null)));
      }));

  Future _doDeletes() => Future.wait(_delete.map((o) async {
        var m = _manager._mapper(o);
        await m.delete(o);
        if (m.notifier != null)
          _addNotifyDelete(o, () => m.notifier._addDelete(new EntityContainer(o, null)));
      }));

  void _doNotifyUpdates() {}

  void _doNotifyInserts() {}

  void _doNotifyDeletes() {}

  Future _begin() => !_started
      ? _manager.connection.execute('BEGIN').then((_) => _started = true)
      : new Future.value();

  Future _commit() =>
      _manager.connection.execute('COMMIT').then((_) => _started = false);

  Future _rollback() =>
      _manager.connection.execute('ROLLBACK').then((_) => _started = false);

  Future persist() async {
    return _begin()
        .then((_) => _doDeletes())
        .then((_) => _doUpdates())
        .then((_) => _doInserts())
        .then((_) => _resetEntities())
        .catchError((e, s) => _rollback().then((_) => new Future.error(e, s)));
  }

  Future commit() {
    return persist()
        .then((_) => _commit())
        .then((_) => _doNotifyDeletes())
        .then((_) => _doNotifyUpdates())
        .then((_) => _doNotifyInserts())
        .then((_) => _resetNotifiers())
        .catchError((e, s) => _rollback().then((_) => new Future.error(e, s)));
  }
}
