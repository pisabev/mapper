part of mapper_server;

typedef EntityFunction<T> = T Function();

abstract class Mapper<E extends Entity<Application>, C extends Collection<E>,
    A extends Application> {
  final Manager<A> manager;

  String table;

  dynamic pkey;

  static const String _SEP = '.';

  EntityFunction<E> entity;

  EntityFunction<C> collection;

  EntityNotifier<E> notifier;

  Mapper(this.manager) {
    pkey ??= '${table}_id';
  }

  Future<E> find(dynamic id, [bool no_cache = false]) {
    if (id is List) return findComposite(id);
    final cache_key = id.toString();
    final e = _cacheGet(cache_key);
    if (e != null) {
      return new Future.value(e);
    } else {
      return _streamToEntity(selectBuilder()
        ..where('${_escape(pkey)} = @pkey')
        ..setParameter('pkey', id));
    }
  }

  Future<E> findComposite(List<dynamic> ids, [bool no_cache = false]) {
    final cache_key = ids.join(_SEP);
    final e = _cacheGet(cache_key);
    if (e != null) {
      return new Future.value(e);
    } else {
      final q = selectBuilder();
      var i = 0;
      ids.forEach((k) {
        final key = 'pkey$i';
        q
          ..andWhere('${_escape(pkey[i])} = @$key')
          ..setParameter(key, k);
        i++;
      });
      return _streamToEntity(q);
    }
  }

  Future<C> findAll() => loadC(selectBuilder());

  Builder queryBuilder() => new Builder();

  Builder selectBuilder([String select = '*']) => new Builder()
    ..select(select)
    ..from(_escape(table));

  Builder deleteBuilder() => new Builder()..delete(_escape(table));

  Builder insertBuilder() => new Builder()..insert(_escape(table));

  Builder updateBuilder() => new Builder()..update(_escape(table));

  Future<E> loadE(Builder builder) => _streamToEntity(builder)
      .catchError((e) => manager._error(e, builder.getSQL(), builder._params));

  Future<C> loadC(Builder builder, [bool calcTotal = false]) =>
      _streamToCollection(builder, calcTotal).catchError(
          (e) => manager._error(e, builder.getSQL(), builder._params));

  Future<E> insert(E object) async {
    final data = readObject(object);
    final result = await execute(_setUpdateData(insertBuilder(), data, true));
    setObject(object, result[0]);
    final d = readObject(object);
    _cacheAdd(_cacheKeyFromData(d), object, notifier != null ? d : null);
    await _notifyCreate(object);
    return object;
  }

  Future<E> update(E object) async {
    final data = readObject(object);
    final q = _setUpdateData(updateBuilder(), data);
    if (pkey is List)
      pkey.forEach((k) => q
        ..andWhere('${_escape(k)} = @$k')
        ..setParameter(k, data[k]));
    else
      q
        ..andWhere('${_escape(pkey)} = @$pkey')
        ..setParameter(pkey, data[pkey]);
    await execute(q);
    await _notifyUpdate(object);
    return object;
  }

  Future<bool> delete(E object) {
    final data = readObject(object);
    return (pkey is List)
        ? _deleteComposite(pkey.map((k) => data[k]), object)
        : _deleteById(data[pkey], object);
  }

  Future<bool> deleteById(dynamic id) =>
      find(id).then((object) => _deleteById(id, object));

  Future<bool> deleteComposite(Iterable<dynamic> ids) =>
      findComposite(ids).then((object) => _deleteComposite(ids, object));

  Future<bool> _deleteById(dynamic id, E object) async {
    _cacheClean(id.toString());
    await _notifyDelete(object);
    await execute(deleteBuilder()
      ..where('${_escape(pkey)} = @$pkey')
      ..setParameter(pkey, id));
    return true;
  }

  Future<bool> _deleteComposite(Iterable<dynamic> ids, E object) async {
    await _notifyDelete(object);
    _cacheClean(ids.join(_SEP));
    final q = deleteBuilder();
    var i = 0;
    ids.forEach((k) {
      final key = 'pkey$i';
      q
        ..andWhere('${_escape(pkey[i])} = @$key')
        ..setParameter(key, k);
      i++;
    });
    await execute(q);
    return true;
  }

  Map<String, dynamic> _readDiff(E obj) {
    final newData = readObject(obj);
    final key = _cacheKeyFromData(newData);
    final oldData = _cacheGetInitData(key);
    final diffm = <String, dynamic>{};
    if (oldData != null) {
      newData.forEach((k, v) {
        final oldValue = oldData[k];
        if (oldValue != v) diffm[k] = oldValue;
      });
    }
    return diffm;
  }

  Future _notifyUpdate(E obj) async {
    if (notifier != null) {
      final diffm = _readDiff(obj);
      if (diffm.isNotEmpty) {
        if (!manager.inTransaction)
          await notifier._addUpdate(new EntityContainer(obj, diffm));
        else
          manager._unit._addNotifyUpdate(
              obj, () => notifier._addUpdate(new EntityContainer(obj, diffm)));
      }
    }
  }

  Future _notifyCreate(E obj) async {
    if (notifier != null) {
      if (!manager.inTransaction)
        await notifier._addCreate(new EntityContainer(obj, null));
      else
        manager._unit._addNotifyInsert(
            obj, () => notifier._addCreate(new EntityContainer(obj, null)));
    }
  }

  Future _notifyDelete(E obj) async {
    if (notifier != null) {
      if (!manager.inTransaction)
        await notifier._addDelete(new EntityContainer(obj, null));
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
          ..set(_escape(k), v is List ? '@$k:jsonb' : '@$k')
          ..setParameter(k, v);
    });
    return builder;
  }

  E _onStreamRow(data) {
    final key = _cacheKeyFromData(data);
    if (key == null) throw new Exception('Pkey value not found!');
    var object = _cacheGet(key);
    if (object != null) return object;
    object = createObject(data);
    _cacheAdd(key, object, notifier != null ? readObject(object) : null);
    return object;
  }

  Future<List> execute(Builder builder) => manager._connection
      .query(builder.getSQL(), substitutionValues: builder._params)
      .catchError((e) => manager._error(e, builder.getSQL(), builder._params));

  Future<E> _streamToEntity(Builder builder) async {
    final res = await manager._connection
        .queryToEntityCollection(
            builder.getSQL(), _onStreamRow, createCollection(),
            substitutionValues: builder._params)
        .catchError(
            (e) => manager._error(e, builder.getSQL(), builder._params));
    return res.isEmpty ? null : res.first;
  }

  Future<C> _streamToCollection(Builder builder, [calcTotal = false]) async {
    if (calcTotal) builder.addSelect('COUNT(*) OVER() AS __total__');
    return manager._connection.queryToEntityCollection(
        builder.getSQL(), _onStreamRow, createCollection(),
        substitutionValues: builder._params);
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
    q ??= selectBuilder();
    return new CollectionBuilder<E, C, A>(q, this);
  }

  String _escape(String string) => '"$string"';

  E createObject([dynamic data]) {
    final object = entity().._mapper = this;
    if (data != null) object.init(data);
    return object;
  }

  C createCollection() => collection();

  void setObject(E object, Map data) => object.init(data);

  Map readObject(E object) => object.toMap();

  E mergeData(E object, Map data) {
    final m = readObject(object)..addAll(data);
    setObject(object, m);
    return object;
  }

  Future<E> prepare(dynamic vpkey, Map data, {bool forceInsert = false}) async {
    if (vpkey != null) {
      final object =
          (vpkey is List) ? await findComposite(vpkey) : await find(vpkey);
      data[pkey] = vpkey;
      if (object == null && forceInsert) {
        final object = createObject(data);
        manager.addNew(object);
        return object;
      } else {
        mergeData(object, data);
        manager.addDirty(object);
        return object;
      }
    } else {
      final object = createObject(data);
      manager.addNew(object);
      return object;
    }
  }
}
