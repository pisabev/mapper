part of mapper_server;

class Manager<A extends Application> {
  A app;

  Unit<A> _unit;

  Cache _cache;

  Connection _connection;

  var connection;

  Map session;

  Manager(Connection conn, A application) {
    _unit = new Unit(this);
    _cache = new Cache();
    _connection = conn;
    app = application;
    app.m = this;
  }

  Future<Manager> init([String debugId]) {
    return _connection.connect(debugId).then((c) {
      connection = c;
      return this;
    });
  }

  Future destroy() => _connection._pool.stop();

  Future query(query, [params]) => connection.query(query, params).toList();

  builder() => new Builder(connection);

  cacheAdd(String key, Entity<A> object, Map initData) =>
      _cache.add(key, object, initData);

  cacheClean(String key) => _cache.delete(key);

  Entity<A> cacheGet(String key) => _cache.get(key);

  Map cacheGetInitData(String key) => _cache.getInitData(key);

  cache() => _cache.toString();

  addDirty(Entity<A> object) => _unit.addDirty(object);

  addNew(Entity<A> object) => _unit.addNew(object);

  addDelete(Entity<A> object) => _unit.addDelete(object);

  Future persist() => _unit.persist();

  Future commit() => _unit.commit();

  Future begin() => _unit._begin();

  Future rollback() => _unit._rollback();

  bool get inTransaction => _unit._started;

  Future close() async {
    _cache = new Cache();
    if (_unit._started) await _unit._rollback();
    return connection.close();
  }

  Mapper _mapper(Entity<A> object) => Mapper._ref[object.runtimeType.toString()];
}
