part of mapper_server;

typedef T EntityFunction<T>();

abstract class Mapper<E extends Entity<A>, C extends Collection<E>,
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
      return selectBuilder()
          .where(_escape(pkey) + ' = @pkey')
          .setParameter('pkey', id)
          .stream(_streamToEntity);
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
      return q.stream(_streamToEntity);
    }
  }

  Future<C> findAll() => loadC(selectBuilder());

  Builder queryBuilder() => new Builder(manager.connection);

  Builder selectBuilder([String select = '*']) =>
      new Builder(manager.connection).select(select).from(_escape(table));

  Builder deleteBuilder() =>
      new Builder(manager.connection).delete(_escape(table));

  Builder insertBuilder() =>
      new Builder(manager.connection).insert(_escape(table));

  Builder updateBuilder() =>
      new Builder(manager.connection).update(_escape(table));

  Future<E> loadE(Builder builder) => builder.stream(_streamToEntity);

  Future<C> loadC(Builder builder) => builder.stream(_streamToCollection);

  Future<E> insert(E object) {
    Map data = readObject(object);
    return _setUpdateData(insertBuilder(), data, true).execute().then((result) {
      setObject(object, result[0].toMap());
      _cacheAdd(_cacheKeyFromData(data), object, notifier != null? readObject(object) : null);
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
    return q.stream((stream) => stream.drain(object)).then((E obj) {
      _notifyUpdate(obj, data);
      return obj;
    });
  }

  Future<bool> delete(E object) {
    Map data = readObject(object);
    return (pkey is List)
        ? _deleteComposite(pkey.map((k) => data[k]), object)
        : _deleteById(data[pkey], object);
  }

  Future<bool> refresh(E object) {
    var data = readObject(object);
    if (pkey is List) {
      Builder q = selectBuilder();
      int i = 0;
      pkey.forEach((k) {
        String key = 'pkey' + i.toString();
        q.andWhere(_escape(pkey[k]) + ' = @' + key).setParameter(key, k);
        i++;
      });
      return q.execute().then((data) {
        mergeData(object, data.first.toMap());
        return true;
      });
    } else {
      var id = data[pkey];
      return selectBuilder()
          .where(_escape(pkey) + ' = @pkey')
          .setParameter('pkey', id)
          .execute()
          .then((data) {
        mergeData(object, data.first.toMap());
        return true;
      });
    }
  }

  Future<bool> deleteById(dynamic id) =>
      find(id).then((E object) => _deleteById(id, object));

  Future<bool> deleteComposite(Iterable<dynamic> ids) =>
      findComposite(ids).then((E object) => _deleteComposite(ids, object));

  Future<bool> _deleteById(dynamic id, E object) async {
    _cacheClean(id.toString());
    _notifyDelete(object);
    return deleteBuilder()
        .where(_escape(pkey) + ' = @' + pkey)
        .setParameter(pkey, id)
        .stream((Stream stream) => stream.drain(true));
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
    return q.stream((Stream stream) => stream.drain(true));
  }

  _notifyUpdate(E obj, Map newData) {
    if (notifier != null) {
      var key = _cacheKeyFromData(newData);
      var oldData = _cacheGetInitData(key);
      var diffm = {};
      newData.forEach((k, v) {
        var oldValue = oldData[k];
        if (oldValue != v) diffm[k] = oldValue;
      });
      var cont = new EntityContainer(obj, diffm);
      if (!manager.inTransaction)
        notifier._addUpdate(cont);
      else
        manager._unit._addNotifyUpdate(cont);
    }
  }

  void _notifyCreate(E obj) {
    if (notifier != null) {
      var cont = new EntityContainer(obj, null);
      if (!manager.inTransaction)
        notifier._addCreate(cont);
      else
        manager._unit._addNotifyCreate(cont);
    }
  }

  void _notifyDelete(E obj) {
    if (notifier != null) {
      var cont = new EntityContainer(obj, null);
      if (!manager.inTransaction)
        notifier._addDelete(cont);
      else
        manager._unit._addNotifyDelete(cont);
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
    E object = _cacheGet(key);
    if (object != null) return object;
    object = createObject(data);
    _cacheAdd(key, object, notifier != null? readObject(object) : null);
    return object;
  }

  Future<E> _streamToEntity(Stream stream) {
    return stream
        .map(_onStreamRow)
        .toList()
        .then((list) => (list.length > 0) ? list[0] : null);
  }

  Future<C> _streamToCollection(Stream stream) {
    return stream.map(_onStreamRow).toList().then((list) {
      C col = createCollection();
      col.addAll(list);
      return col;
    });
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
}
