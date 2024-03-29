part of mapper_server;

class Unit {
  final Manager _manager;

  late List<Entity> _dirty;

  late List<Entity> _new;

  late List<Entity> _delete;

  late Map<Entity, Function> _notifyInsert;

  late Map<Entity, Function> _notifyUpdate;

  late Map<Entity, Function> _notifyDelete;

  bool _started = false;

  Unit(this._manager) {
    _resetEntities();
    _resetNotifiers();
  }

  void _resetEntities() {
    _dirty = <Entity>[];
    _new = <Entity>[];
    _delete = <Entity>[];
  }

  void _resetNotifiers() {
    _notifyInsert = {};
    _notifyUpdate = {};
    _notifyDelete = {};
  }

  void addDirty(Entity object) =>
      (!_new.contains(object) && !_dirty.contains(object))
          ? _dirty.add(object)
          : null;

  void addNew(Entity object) =>
      (!_new.contains(object)) ? _new.add(object) : null;

  void addDelete(Entity object) {
    if (!_delete.contains(object)) _delete.add(object);
    if (_new.contains(object)) _new.remove(object);
  }

  void _addNotifyUpdate(Entity object, Function f) =>
      (!_notifyInsert.containsKey(object)) ? _notifyUpdate[object] = f : null;

  void _addNotifyInsert(Entity object, Function f) =>
      (!_notifyInsert.containsKey(object)) ? _notifyInsert[object] = f : null;

  void _addNotifyDelete(Entity object, Function f) {
    if (!_notifyDelete.containsKey(object)) _notifyDelete[object] = f;
    if (_notifyInsert.containsKey(object)) _notifyInsert.remove(object);
  }

  Future _doUpdates() =>
      Future.forEach<Entity>(_dirty, (o) => o._mapper.update(o));

  Future _doInserts() =>
      Future.forEach<Entity>(_new, (o) => o._mapper.insert(o));

  Future _doDeletes() =>
      Future.forEach<Entity>(_delete, (o) => o._mapper.delete(o));

  void _doNotifyUpdates() => _notifyUpdate.values.forEach((v) => v());

  void _doNotifyInserts() => _notifyInsert.values.forEach((v) => v());

  void _doNotifyDeletes() => _notifyDelete.values.forEach((v) => v());

  Future _begin() => !_started
      ? _manager._connection!.execute('BEGIN').then((_) => _started = true)
      : new Future.value();

  Future _commit() =>
      _manager._connection!.execute('COMMIT').then((_) => _started = false);

  Future _savePoint(String savePoint) =>
      _manager._connection!.execute('SAVEPOINT $savePoint');

  Future _releaseSavePoint(String savePoint) =>
      _manager._connection!.execute('RELEASE SAVEPOINT $savePoint');

  Future _rollback([String? savePoint]) => savePoint != null
      ? _manager._connection!.execute('ROLLBACK TO SAVEPOINT $savePoint')
      : _manager._connection!.execute('ROLLBACK').then((_) => _started = false);

  Future persist() => _begin()
      .then((_) => _doDeletes())
      .then((_) => _doUpdates())
      .then((_) => _doInserts())
      .then((_) => _resetEntities())
      .catchError((e, s) => _rollback().then((_) => new Future.error(e, s)));

  Future commit() => persist().then((_) => _commit()).then((_) {
        _doNotifyDeletes();
        _doNotifyUpdates();
        _doNotifyInserts();
        _resetNotifiers();
      });
}
