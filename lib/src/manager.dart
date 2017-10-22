part of mapper_server;

class Manager<A extends Application> {
  A app;

  Unit<Application> _unit;

  Cache _cache;

  Pool _pool;

  drv.PostgreSQLConnection _connection;

  Map session;

  Manager(Pool pool, A application) {
    _unit = new Unit(this);
    _cache = new Cache();
    _pool = pool;
    app = application;
    app.m = this;
  }

  Future<Manager> init() async {
    _connection = await _pool.obtain();
    return this;
  }

  //Future destroy() => _pool.stop();

  Map _rowToMap(Iterable row) {
    var m = {};
    row.forEach((r) => m[r[0]] = r[1]);
    return m;
  }

  Future<List> query(String query, [Map params]) =>
      _connection.query(query, substitutionValues: params).then((rows) {
        if (rows.isEmpty) return [];
        return rows.map(_rowToMap).toList();
      }).catchError((e) => _error(e, query, params));

  Future<List> execute(Builder builder) => _connection
          .query(builder.getSQL(), substitutionValues: builder._params)
          .then((rows) {
        if (rows.isEmpty) return [];
        return rows.map(_rowToMap).toList();
      }).catchError((e) => _error(e, builder.getSQL(), builder._params));

  _error(e, [String query, Map params]) {
    if (e is drv.PostgreSQLException) {
      if (e.code != null && (e.code == '23503' || e.code == '23514'))
        throw new PostgreConstraintException(
            e.toString(), query, params?.toString(), e);
      else
        throw new PostgreQueryException(
            e.toString(), query, params?.toString(), e);
    } else {
      throw new MapperException(e.toString(), query, params?.toString());
    }
  }

  cacheAdd(String key, Entity<Application> object, Map initData) =>
      _cache.add(key, object, initData);

  cacheClean(String key) => _cache.delete(key);

  Entity<Application> cacheGet(String key) => _cache.get(key);

  Map cacheGetInitData(String key) => _cache.getInitData(key);

  cache() => _cache.toString();

  addDirty(Entity<Application> object) => _unit.addDirty(object);

  addNew(Entity<Application> object) => _unit.addNew(object);

  addDelete(Entity<Application> object) => _unit.addDelete(object);

  Future persist() => _unit.persist();

  Future commit() => _unit.commit();

  Future begin() => _unit._begin();

  Future rollback() => _unit._rollback();

  bool get inTransaction => _unit._started;

  Future close() async {
    _cache = new Cache();
    if (_unit._started) await _unit._rollback();
    return _pool.release(_connection);
  }

  Mapper _mapper(Entity<Application> object) =>
      Mapper._ref[object.runtimeType.toString()];
}
