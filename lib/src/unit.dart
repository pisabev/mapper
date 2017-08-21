part of mapper_server;

class Unit<A extends Application> {
  Manager _manager;

  List<Entity> _dirty;

  List<Entity> _new;

  List<Entity> _delete;

  bool _started = false;

  Unit(Manager manager) {
    _manager = manager;
    _resetEntities();
  }

  _resetEntities() {
    _dirty = new List<Entity<A>>();
    _new = new List<Entity<A>>();
    _delete = new List<Entity<A>>();
  }

  void addDirty(Entity<A> object) =>
      (!_new.contains(object) && !_dirty.contains(object))
          ? _dirty.add(object)
          : null;

  void addNew(Entity<A> object) =>
      (!_new.contains(object)) ? _new.add(object) : null;

  void addDelete(Entity<A> object) =>
      (!_delete.contains(object)) ? _delete.add(object) : null;

  Future _doUpdates() =>
      Future.wait(_dirty.map((o) async {
        var m = _manager._mapper(o);
        await m.update(o);
        if(m.notifier != null) {
          var diffm = m._readDiff(o);
          if (diffm.isNotEmpty)
            m.notifier._addUpdate(new EntityContainer(o, diffm));
        }
      }));

  Future _doInserts() =>
      Future.wait(_new.map((o) async {
        var m = _manager._mapper(o);
        await m.insert(o);
        if(m.notifier != null)
          m.notifier._addCreate(new EntityContainer(o, null));
      }));

  Future _doDeletes() =>
      Future.wait(_delete.map((o) async {
        var m = _manager._mapper(o);
        await m.delete(o);
        if(m.notifier != null)
          m.notifier._addDelete(new EntityContainer(o, null));
      }));

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
        .catchError((e, s) => _rollback().then((_) => new Future.error(e, s)));
  }
}
