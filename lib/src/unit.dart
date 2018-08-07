part of mapper_server;

class Unit {
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
    _dirty = new List<Entity>();
    _new = new List<Entity>();
    _delete = new List<Entity>();
  }

  _resetNotifiers() {
    _notifyInsert = new Map();
    _notifyUpdate = new Map();
    _notifyDelete = new Map();
  }

  void addDirty(Entity object) =>
      (!_new.contains(object) && !_dirty.contains(object))
          ? _dirty.add(object)
          : null;

  void addNew(Entity object) =>
      (!_new.contains(object)) ? _new.add(object) : null;

  void addDelete(Entity object) {
    (!_delete.contains(object)) ? _delete.add(object) : null;
    if (_new.contains(object)) _new.remove(object);
  }

  void _addNotifyUpdate(Entity object, Function f) =>
      (!_notifyInsert.containsKey(object) && !_notifyUpdate.containsKey(object))
          ? _notifyUpdate[object] = f
          : null;

  void _addNotifyInsert(Entity object, Function f) =>
      (!_notifyInsert.containsKey(object)) ? _notifyInsert[object] = f : null;

  void _addNotifyDelete(Entity object, Function f) {
    (!_notifyDelete.containsKey(object)) ? _notifyDelete[object] = f : null;
    if (_notifyInsert.containsKey(object)) _notifyInsert.remove(object);
  }

  Future _doUpdates() => Future.forEach(_dirty, ((o) => o._mapper.update(o)));

  Future _doInserts() => Future.forEach(_new, ((o) => o._mapper.insert(o)));

  Future _doDeletes() => Future.forEach(_delete, ((o) => o._mapper.delete(o)));

  Future _doNotifyUpdates() => Future.forEach(_notifyUpdate.values, (v) => v());

  Future _doNotifyInserts() => Future.forEach(_notifyInsert.values, (v) => v());

  Future _doNotifyDeletes() => Future.forEach(_notifyDelete.values, (v) => v());

  Future _begin() => !_started
      ? _manager._connection.execute('BEGIN').then((_) => _started = true)
      : new Future.value();

  Future _commit() =>
      _manager._connection.execute('COMMIT').then((_) => _started = false);

  Future _savePoint(String savePoint) =>
      _manager._connection.execute('SAVEPOINT $savePoint');

  Future _releaseSavePoint(String savePoint) =>
      _manager._connection.execute('RELEASE SAVEPOINT $savePoint');

  Future _rollback([String savePoint]) => savePoint != null
      ? _manager._connection.execute('ROLLBACK TO SAVEPOINT $savePoint')
      : _manager._connection.execute('ROLLBACK').then((_) => _started = false);

  Future persist() {
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
