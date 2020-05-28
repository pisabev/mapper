part of mapper_server;

abstract class Mapper<E extends Entity<Application>, C extends Collection<E>,
    A extends Application> extends MapperBase<E, C, A> {
  String table;

  dynamic pkey;

  static const String _SEP = '.';

  EntityNotifier<E> notifier;

  Mapper(manager) : super(manager) {
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

  Future<T> findWhere<T>(List<Expression> expr) {
    final b = selectBuilder();
    expr.forEach((e) => e._evaluate(b));
    return T == C ? loadC(b) : loadE(b);
  }

  Future<C> findAll() => loadC(selectBuilder());

  Builder selectBuilder([String select]) {
    final tbl = _escape(table);
    select ??= '$tbl.*';
    return new Builder()
      ..select(select)
      ..from(tbl);
  }

  Builder deleteBuilder() => new Builder()..delete(_escape(table));

  Builder insertBuilder() => new Builder()..insert(_escape(table));

  Builder updateBuilder() => new Builder()..update(_escape(table));

  Future<E> insert(E object) async {
    final data = readObject(object);
    final result = await execute(_setUpdateData(insertBuilder(), data, true));
    setObject(object, result[0]);
    final d = readObject(object);
    _cacheAdd(_cacheKeyFromData(d), object, notifier != null ? d : null);
    _notifyCreate(object);
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
    _notifyUpdate(object);
    return object;
  }

  Future<bool> delete(E object) async {
    if (object == null) return false;
    final data = readObject(object);
    return (pkey is List)
        ? _deleteComposite(pkey.map((k) => data[k]), object)
        : _deleteById(data[pkey], object);
  }

  Future<bool> deleteById(dynamic id) => find(id).then(delete);

  Future<bool> deleteComposite(Iterable<dynamic> ids) =>
      findComposite(ids).then((object) => _deleteComposite(ids, object));

  Future<bool> _deleteById(dynamic id, E object) async {
    _cacheClean(id.toString());
    await execute(deleteBuilder()
      ..where('${_escape(pkey)} = @$pkey')
      ..setParameter(pkey, id));
    _notifyDelete(object);
    return true;
  }

  Future<bool> _deleteComposite(Iterable<dynamic> ids, E object) async {
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
    _notifyDelete(object);
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

  void _notifyUpdate(E obj) {
    if (notifier != null) {
      final diffm = _readDiff(obj);
      if (diffm.isNotEmpty) {
        if (!manager.inTransaction)
          notifier._addUpdate(new EntityContainer(obj, diff: diffm));
        else
          manager._unit._addNotifyUpdate(obj,
              () => notifier._addUpdate(new EntityContainer(obj, diff: diffm)));
      }
    }
  }

  void _notifyCreate(E obj) {
    if (notifier != null) {
      if (!manager.inTransaction)
        notifier._addCreate(new EntityContainer(obj));
      else
        manager._unit._addNotifyInsert(
            obj, () => notifier._addCreate(new EntityContainer(obj)));
    }
  }

  void _notifyDelete(E obj) {
    if (notifier != null) {
      if (!manager.inTransaction)
        notifier._addDelete(new EntityContainer(obj, deleted: true));
      else
        manager._unit._addNotifyDelete(obj,
            () => notifier._addDelete(new EntityContainer(obj, deleted: true)));
    }
  }

  Builder _setUpdateData(Builder builder, data, [bool insert = false]) {
    data.forEach((k, v) {
      if (v == null && insert)
        builder.set(_escape(k), 'DEFAULT');
      else {
//        if (v is String) {
//          builder.set(_escape(k), '@$k:text');
//        } else
        if (v is bool) {
          builder.set(_escape(k), '@$k:boolean');
        } else if (v is List) {
          builder.set(_escape(k), '@$k:jsonb');
        } else {
          builder.set(_escape(k), '@$k');
        }
        builder.setParameter(k, v);
      }
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

  void setObject(E object, Map data) => object.init(data);

  Map<String, dynamic> readObject(E object) => object.toMap();

  E mergeData(E object, Map<String, dynamic> data) {
    final m = readObject(object)..addAll(data);
    setObject(object, m);
    return object;
  }

  Future<List<E>> crud(Map<String, List> data,
      [String fKey, dynamic fKeyValue]) async {
    final insertList = data['insert'];
    final deleteList = data['delete'];
    final updateList = data['update'];
    final res = <E>[];
    if (deleteList != null) {
      for (final r in deleteList) {
        final ent = await find(r[pkey]);
        manager.addDelete(ent);
      }
    }
    if (updateList != null) {
      for (final r in updateList) res.add(await prepare(r[pkey], r));
    }
    if (insertList != null) {
      for (final r in insertList) {
        if (fKey != null && fKeyValue != null) r[fKey] = fKeyValue;
        res.add(await prepare(null, r));
      }
    }
    return res;
  }

  Future<E> prepare(dynamic vpkey, Map<String, dynamic> data,
      {bool forceInsert = false}) async {
    if (vpkey != null) {
      E object;
      if (vpkey is List) {
        object = await findComposite(vpkey);
        for (var i = 0; i < (pkey as List).length; i++)
          data[pkey[i]] = vpkey[i];
      } else {
        object = await find(vpkey);
        data[pkey] = vpkey;
      }
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

  Future<void> mergePK(dynamic obsoletePk, dynamic newPk,
      {Set<String> exclude}) async {
    if (obsoletePk == newPk) return;
    final col = await manager.execute(new Builder()
      ..select('tc.table_name, kcu.column_name')
      ..from('information_schema.table_constraints tc')
      ..join('information_schema.key_column_usage kcu',
          'tc.constraint_name = kcu.constraint_name')
      ..join('information_schema.constraint_column_usage ccu',
          'ccu.constraint_name = tc.constraint_name')
      ..where("constraint_type = 'FOREIGN KEY'", "ccu.table_name='$table'"));
    if (col.isNotEmpty) {
      exclude ??= {};
      for (final r in col.where((r) => !exclude.contains(r['table_name']))) {
        await manager.execute(new Builder()
          ..update(r['table_name'])
          ..set(r['column_name'], newPk)
          ..where('${r['column_name']} = @obs')
          ..setParameter('obs', obsoletePk));
      }
      await deleteById(obsoletePk);
    }
  }

  Future<String> genPatch(
      {C collection, String constraintKey, bool disableTriggers = true}) async {
    final constraint = constraintKey != null
        ? 'ON CONSTRAINT $constraintKey'
        : (pkey is List ? '(${pkey.join(',')})' : '($pkey)');
    collection ??= await findAll();
    final sb = new StringBuffer();
    if (disableTriggers) sb.write('ALTER TABLE $table DISABLE TRIGGER USER;\n');
    for (final object in collection) {
      final m = object.toMap();
      sb
        ..write('INSERT INTO $table ')
        ..write('("${m.keys.join('","')}") VALUES ')
        ..write('(${m.values.map((v) {
          if (v is DateTime)
            return "'${v.toIso8601String()}'";
          else if (v is List || v is Map)
            return "'${jsonEncode(v)}'";
          else if (v is String) return "'$v'";
          return v;
        }).join(',')}) ')
        ..write('ON CONFLICT $constraint ')
        ..write('DO UPDATE SET ')
        ..write(m.keys.map((k) => '"$k" = EXCLUDED.$k').join(','))
        ..write(';\n');
    }
    if (disableTriggers) sb.write('ALTER TABLE $table ENABLE TRIGGER USER;\n');
    return sb.toString();
  }
}
