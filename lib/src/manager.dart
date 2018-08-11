part of mapper_server;

class Manager<A extends Application> {
  Unit _unit;

  Cache _cache;

  Pool _pool;

  A app;

  drv.PostgreSQLConnection _connection;

  Manager(this._pool, [this.app]) {
    _unit = new Unit(this);
    _cache = new Cache();
    app?.m = this;
  }

  Manager._convert(
      this._pool, this.app, this._connection, this._cache, this._unit) {
    app.m = this;
  }

  Future init() async {
    _connection = await _pool.obtain();
  }

  Manager<T> convert<T extends Application>(T app) => (app is Manager<A>)
      ? this
      : new Manager<T>._convert(_pool, app, _connection, _cache, _unit);

  Future<List> query(String query, [Map params]) => _connection
      .query(query, substitutionValues: params)
      .catchError((e) => _error(e, query, params));

  Future<List> execute(Builder builder) => _connection
      .query(builder.getSQL(), substitutionValues: builder._params)
      .catchError((e) => _error(e, builder.getSQL(), builder._params));

  _error(e, [String query, Map params]) {
    if (e is drv.PostgreSQLException) {
      if (e.code != null &&
          (e.code == '23500' ||
              e.code == '23501' ||
              e.code == '23502' ||
              e.code == '23503' ||
              e.code == '23505' ||
              e.code == '23514'))
        throw new PostgreConstraintException(
            e.toString(), query, params?.toString(), e);
      else
        throw new PostgreQueryException(
            e.toString(), query, params?.toString(), e);
    } else {
      throw new MapperException(e.toString(), query, params?.toString());
    }
  }

  cacheAdd(String key, Entity object, Map initData) =>
      _cache.add(key, object, initData);

  cacheClean(String key) => _cache.delete(key);

  Entity cacheGet(String key) => _cache.get(key);

  Map cacheGetInitData(String key) => _cache.getInitData(key);

  cache() => _cache.toString();

  addDirty(Entity object) => _unit.addDirty(object);

  addNew(Entity object) => _unit.addNew(object);

  addDelete(Entity object) => _unit.addDelete(object);

  Future persist() => _unit.persist();

  Future commit() => _unit.commit();

  Future begin() => _unit._begin();

  Future savePoint(String savePoint) => _unit._savePoint(savePoint);

  Future releaseSavePoint(String savePoint) =>
      _unit._releaseSavePoint(savePoint);

  Future rollback([String savePoint]) => _unit._rollback(savePoint);

  bool get inTransaction => _unit._started;

  Future close() async {
    _cache = new Cache();
    if (_unit._started) await _unit._rollback();
    _pool.release(_connection);
    _connection = null;
  }
}
