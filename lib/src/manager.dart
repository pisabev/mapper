part of mapper_server;

class Manager {
  Unit _unit;

  Cache _cache;

  final Pool _pool;

  App app;

  drv.PostgreSQLConnection _connection;

  Manager(this._pool) {
    _unit = new Unit(this);
    _cache = new Cache();
    app = new App(this);
  }

  Future init() async {
    _connection = await _pool.obtain();
  }

  Future<List<Map<String, dynamic>>> query(String query, [Map params]) =>
      _connection
          .query(query, substitutionValues: params)
          .catchError((e) => _error(e, query, params));

  Future<List<Map<String, dynamic>>> execute(Builder builder) => _connection
      .query(builder.getSQL(), substitutionValues: builder._params)
      .catchError((e) => _error(e, builder.getSQL(), builder._params));

  void _error(e, [String query, Map params]) {
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

  void cacheAdd(String key, Entity object, Map initData) =>
      _cache.add(key, object, initData);

  void cacheClean(String key) => _cache.delete(key);

  Entity cacheGet(String key) => _cache.get(key);

  Map cacheGetInitData(String key) => _cache.getInitData(key);

  void cache() => _cache.toString();

  void addDirty(Entity object) => _unit.addDirty(object);

  void addNew(Entity object) => _unit.addNew(object);

  void addDelete(Entity object) => _unit.addDelete(object);

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
