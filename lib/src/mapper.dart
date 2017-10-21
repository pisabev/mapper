part of mapper_server;

typedef T EntityFunction<T>();

abstract class Mapper<E extends Entity<Application>, C extends Collection<E>,
    A extends Application> {
  Manager<A> manager;

  @virtual
  String table;

  @virtual
  dynamic pkey;

  static Map<String, Object> _ref = new Map();

  static const String _SEP = '.';

  EntityFunction<E> entity;

  EntityFunction<C> collection;

  EntityNotifier<E> notifier;

  Mapper() {
    if (pkey == null) pkey = table + '_id';
  }

  Future<E> find(dynamic id, [no_cache = false]) {
    if (id is List) return findComposite(id);
    String cache_key = id.toString();
    E e = _cacheGet(cache_key);
    if (e != null) {
      return new Future.value(e);
    } else {
      return _streamToEntity(selectBuilder()
          .where(_escape(pkey) + ' = @pkey')
          .setParameter('pkey', id));
    }
  }

  Future<E> findComposite(List<dynamic> ids, [no_cache = false]) {
    String cache_key = ids.join(_SEP);
    E e = _cacheGet(cache_key);
    if (e != null) {
      return new Future.value(e);
    } else {
      Builder q = selectBuilder();
      int i = 0;
      ids.forEach((k) {
        String key = 'pkey' + i.toString();
        q.andWhere(_escape(pkey[i]) + ' = @' + key).setParameter(key, k);
        i++;
      });
      return _streamToEntity(q);
    }
  }

  Future<C> findAll() => loadC(selectBuilder());

  Builder queryBuilder() => new Builder();

  Builder selectBuilder([String select = '*']) =>
      new Builder().select(select).from(_escape(table));

  Builder deleteBuilder() => new Builder().delete(_escape(table));

  Builder insertBuilder() => new Builder().insert(_escape(table));

  Builder updateBuilder() => new Builder().update(_escape(table));

  Future<E> loadE(Builder builder) => _streamToEntity(builder);

  Future<C> loadC(Builder builder) => _streamToCollection(builder);

  Future<E> insert(E object) {
    Map data = readObject(object);
    return execute(_setUpdateData(insertBuilder(), data, true)).then((result) {
      setObject(object, result[0].toMap());
      var d = readObject(object);
      _cacheAdd(_cacheKeyFromData(d), object, notifier != null ? d : null);
      _notifyCreate(object);
      return object;
    });
  }

  Future<E> update(E object) {
    Map data = readObject(object);
    Builder q = _setUpdateData(updateBuilder(), data);
    if (pkey is List)
      pkey.forEach(
          (k) => q.andWhere(_escape(k) + ' = @' + k).setParameter(k, data[k]));
    else
      q.andWhere(_escape(pkey) + ' = @' + pkey).setParameter(pkey, data[pkey]);
    return execute(q).then((_) {
      _notifyUpdate(object);
      return object;
    });
  }

  Future<bool> delete(E object) {
    Map data = readObject(object);
    return (pkey is List)
        ? _deleteComposite(pkey.map((k) => data[k]), object)
        : _deleteById(data[pkey], object);
  }

  Future<bool> deleteById(dynamic id) =>
      find(id).then((E object) => _deleteById(id, object));

  Future<bool> deleteComposite(Iterable<dynamic> ids) =>
      findComposite(ids).then((E object) => _deleteComposite(ids, object));

  Future<bool> _deleteById(dynamic id, E object) async {
    _cacheClean(id.toString());
    _notifyDelete(object);
    return execute(deleteBuilder()
            .where(_escape(pkey) + ' = @' + pkey)
            .setParameter(pkey, id))
        .then((_) => true);
  }

  Future<bool> _deleteComposite(Iterable<dynamic> ids, E object) async {
    _notifyDelete(object);
    _cacheClean(ids.join(_SEP));
    Builder q = deleteBuilder();
    int i = 0;
    ids.forEach((k) {
      String key = 'pkey' + i.toString();
      q.andWhere(_escape(pkey[i]) + ' = @' + key).setParameter(key, k);
      i++;
    });
    return execute(q).then((_) => true);
  }

  Map _readDiff(E obj) {
    var newData = readObject(obj);
    var key = _cacheKeyFromData(newData);
    var oldData = _cacheGetInitData(key);
    var diffm = {};
    if (oldData != null) {
      newData.forEach((k, v) {
        var oldValue = oldData[k];
        if (oldValue != v) diffm[k] = oldValue;
      });
    }
    return diffm;
  }

  void _notifyUpdate(E obj) {
    if (notifier != null) {
      var diffm = _readDiff(obj);
      if (diffm.isNotEmpty) {
        if (!manager.inTransaction)
          notifier._addUpdate(new EntityContainer(obj, diffm));
        else
          manager._unit._addNotifyUpdate(
              obj, () => notifier._addUpdate(new EntityContainer(obj, diffm)));
      }
    }
  }

  void _notifyCreate(E obj) {
    if (notifier != null) {
      if (!manager.inTransaction)
        notifier._addCreate(new EntityContainer(obj, null));
      else
        manager._unit._addNotifyInsert(
            obj, () => notifier._addCreate(new EntityContainer(obj, null)));
    }
  }

  void _notifyDelete(E obj) {
    if (notifier != null) {
      if (!manager.inTransaction)
        notifier._addDelete(new EntityContainer(obj, null));
      else
        manager._unit._addNotifyDelete(
            obj, () => notifier._addDelete(new EntityContainer(obj, null)));
    }
  }

  Builder _setUpdateData(Builder builder, data, [bool insert = false]) {
    data.forEach((k, v) {
      if (v == null && insert)
        builder.set(_escape(k), 'DEFAULT');
      else
        builder
            .set(_escape(k), v is List ? '@$k:jsonb' : '@$k')
            .setParameter(k, v);
    });
    return builder;
  }

  E _onStreamRow(row) {
    Map data = row.toMap();
    String key = _cacheKeyFromData(data);
    if (key == null) throw new Exception('Pkey value not found!');
    E object = _cacheGet(key);
    if (object != null) return object;
    object = createObject(data);
    _cacheAdd(key, object, notifier != null ? readObject(object) : null);
    return object;
  }

  Future<List> execute(Builder builder) => manager._connection
      .query(builder.getSQL(), builder._params)
      .toList()
      .catchError((e) => _error(builder, e));

  Future<E> _streamToEntity(Builder builder) {
    return manager._connection
        .query(builder.getSQL(), builder._params)
        .map(_onStreamRow)
        .toList()
        .then((list) => (list.length > 0) ? list[0] : null)
        .catchError((e) => _error(builder, e));
  }

  Future<C> _streamToCollection(Builder builder) {
    return manager._connection
        .query(builder.getSQL(), builder._params)
        .map(_onStreamRow)
        .toList()
        .then((list) {
      C col = createCollection();
      col.addAll(list);
      return col;
    }).catchError((e) => _error(builder, e));
  }

  _error(Builder builder, e) {
    if (e is drv.PostgresqlException) {
      if (e.serverMessage != null &&
          (e.serverMessage.code == '23503' || e.serverMessage.code == '23514'))
        throw new PostgreConstraintException(e.toString(), builder.getSQL(),
            builder._params.toString(), e.serverMessage);
      else
        throw new PostgreQueryException(e.toString(), builder.getSQL(),
            builder._params.toString(), e.serverMessage);
    } else {
      throw new MapperException(
          e.toString(), builder.getSQL(), builder._params.toString());
    }
  }

  E _markObject(E object) {
    _ref[object.runtimeType.toString()] = this;
    return object;
  }

  String _cacheKeyFromData(Map data) => (pkey is List)
      ? pkey.map((k) => data[k]).join(_SEP)
      : data[pkey].toString();

  void _cacheAdd(String k, E e, Map initData) {
    manager.cacheAdd(runtimeType.toString() + k, e, initData);
  }

  void _cacheClean(String k) {
    manager.cacheClean(runtimeType.toString() + k);
  }

  E _cacheGet(String k) => manager.cacheGet(runtimeType.toString() + k);

  Map _cacheGetInitData(String k) =>
      manager.cacheGetInitData(runtimeType.toString() + k);

  CollectionBuilder<E, C, A> collectionBuilder([Builder q]) {
    if (q == null) q = selectBuilder();
    return new CollectionBuilder<E, C, A>(q, this);
  }

  String _escape(String string) => '"$string"';

  E createObject([dynamic data]) {
    E object = entity()..manager = manager;
    if (data != null) object.init(data);
    return _markObject(object);
  }

  C createCollection() => collection();

  void setObject(E object, Map data) => object.init(data);

  Map readObject(E object) => object.toMap();

  E mergeData(E object, Map data) {
    Map m = readObject(object);
    m.addAll(data);
    setObject(object, m);
    return object;
  }

  Future<E> prepare(dynamic vpkey, Map data) async {
    if (vpkey != null) {
      E object =
          (vpkey is List) ? await findComposite(vpkey) : await find(vpkey);
      data[pkey] = vpkey;
      mergeData(object, data);
      manager.addDirty(object);
      return object;
    } else {
      E object = createObject(data);
      manager.addNew(object);
      return object;
    }
  }
}
