part of mapper_server;

class Unit {

    Manager _manager;

    List<Entity> _dirty;

    List<Entity> _new;

    List<Entity> _delete;

    List<Entity> _on_create;

    List<Entity> _on_update;

    List<Entity> _on_delete;

    bool _started = false;

    Unit(Manager manager) {
        _manager = manager;
        _resetEntities();
        _resetNotifies();
    }

    _resetEntities() {
        _dirty = new List<Entity>();
        _new = new List<Entity>();
        _delete = new List<Entity>();
    }

    _resetNotifies() {
        _on_create = new List<Entity>();
        _on_update = new List<Entity>();
        _on_delete = new List<Entity>();
    }

    addDirty(Entity object) => (!_new.contains(object) && !_dirty.contains(object))? _dirty.add(object) : null;

    addNew(Entity object) => (!_new.contains(object))? _new.add(object) : null;

    addDelete(Entity object) => (!_delete.contains(object))? _delete.add(object): null;

    Future _doUpdates() => Future.wait(_dirty.map((o) => _manager._mapper(o).update(o)));

    Future _doInserts() => Future.wait(_new.map((o) => _manager._mapper(o).insert(o)));

    Future _doDeletes() => Future.wait(_delete.map((o) => _manager._mapper(o).delete(o)));

    _addNotifyUpdate(Entity object) => !_on_update.contains(object)? _on_update.add(object) : null;

    _addNotifyCreate(Entity object) => !_on_create.contains(object)? _on_create.add(object) : null;

    _addNotifyDelete(Entity object) => !_on_delete.contains(object)? _on_delete.add(object): null;

    void _doUpdateNotifies() => _on_update.forEach((o) => _manager._mapper(o).notifier._addUpdate(o));

    void _doCreateNotifies() => _on_create.forEach((o) => _manager._mapper(o).notifier._addCreate(o));

    void _doDeleteNotifies() => _on_delete.forEach((o) => _manager._mapper(o).notifier._addDelete(o));

    Future _begin() => !_started? _manager.connection.execute('BEGIN').then((_) => _started = true) : null;

    Future _commit() => _manager.connection.execute('COMMIT').then((_) => _started = false);

    Future _rollback() => _manager.connection.execute('ROLLBACK').then((_) => _started = false);

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
        .then((_) => _doUpdateNotifies())
        .then((_) => _doCreateNotifies())
        .then((_) => _doDeleteNotifies())
        .then((_) => _resetNotifies())
        .catchError((e, s) => _rollback().then((_) => new Future.error(e, s)));
    }

}