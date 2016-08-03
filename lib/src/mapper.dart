part of mapper_server;

abstract class Mapper<E extends Entity, C extends Collection<E>, A extends Application> {

    Manager<A> manager;

    String table;

    dynamic pkey;

    static Map _ref = new Map();

    static const String _SEP = '.';

    Function entity;

    Function collection;

    EntityNotifier<E> notifier;

    Mapper() {
        if (pkey == null)
            pkey = table + '_id';
    }

    Future<E> find(dynamic id, [no_cache = false]) {
        if (id is List)
            return findComposite(id);
        String cache_key = id.toString();
        Future<E> f = _cacheGet(cache_key);
        if (f != null) {
            return f;
        } else {
            return _cacheAdd(cache_key, selectBuilder()
            .where(_escape(pkey) + ' = @pkey')
            .setParameter('pkey', id).stream(_streamToEntityFind));
        }
    }

    Future<E> findComposite(List<dynamic> ids, [no_cache = false]) {
        String cache_key = ids.join(_SEP);
        Future<E> f = _cacheGet(cache_key);
        if (f != null) {
            return f;
        } else {
            Builder q = selectBuilder();
            int i = 0;
            ids.forEach((k) {
                String key = 'pkey' + i.toString();
                q.andWhere(_escape(pkey[i]) + ' = @' + key).setParameter(key, k);
                i++;
            });
            return _cacheAdd(cache_key, q.stream(_streamToEntityFind));
        }
    }

    Future<C> findAll() => loadC(selectBuilder());

    Builder queryBuilder() => new Builder(manager.connection);

    Builder selectBuilder([String select = '*']) => new Builder(manager.connection).select(select).from(_escape(table));

    Builder deleteBuilder() => new Builder(manager.connection).delete(_escape(table));

    Builder insertBuilder() => new Builder(manager.connection).insert(_escape(table));

    Builder updateBuilder() => new Builder(manager.connection).update(_escape(table));

    Future<E> loadE(Builder builder) => builder.stream(_streamToEntity);

    Future<C> loadC(Builder builder) => builder.stream(_streamToCollection);

    Future<E> insert(E object) {
        Map data = readObject(object);
        return _setUpdateData(insertBuilder(), data, true)
        .execute().then((result) {
            setObject(object, result[0].toMap());
            return _cacheAdd(_cacheKeyFromData(data), new Future.value(object))
                .then((E obj) {
                    if(notifier != null) notifier._contr_create.add(obj..manager = null);
                    return obj;
                });
        });
    }

    Future<E> update(E object) {
        Map data = readObject(object);
        Builder q = _setUpdateData(updateBuilder(), data);
        if (pkey is List)
            pkey.forEach((k) => q.andWhere(_escape(k) + ' = @' + k).setParameter(k, data[k]));
        else
            q.andWhere(_escape(pkey) + ' = @' + pkey).setParameter(pkey, data[pkey]);
        return q.stream((stream) => stream.drain(object)).then((E obj) {
            if(notifier != null) notifier._contr_update.add(obj..manager = null);
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
        if(pkey is List) {
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
                .execute().then((data) {
                    mergeData(object, data.first.toMap());
                    return true;
                });
        }
    }

    Future<bool> deleteById(dynamic id)
        => find(id).then((E object) => _deleteById(id, object));

    Future<bool> deleteComposite(Iterable<dynamic> ids)
        => findComposite(ids).then((E object) => _deleteComposite(ids, object));

    Future<bool> _deleteById(dynamic id, E object) async {
        _cacheAdd(id.toString(), new Future.value(null));
        if(notifier != null) notifier._contr_delete.add(object..manager = null);
        return deleteBuilder()
        .where(_escape(pkey) + ' = @' + pkey).setParameter(pkey, id)
        .stream((stream) => stream.drain(true));
    }

    Future<bool> _deleteComposite(Iterable<dynamic> ids, E object) async {
        if(notifier != null) notifier._contr_delete.add(object..manager = null);
        _cacheAdd(ids.join(_SEP), new Future.value(null));
        Builder q = deleteBuilder();
        int i = 0;
        ids.forEach((k) {
            String key = 'pkey' + i.toString();
            q.andWhere(_escape(pkey[i]) + ' = @' + key).setParameter(key, k);
            i++;
        });
        return q.stream((stream) => stream.drain(true));
    }

    Builder _setUpdateData(Builder builder, data, [bool insert = false]) {
        data.forEach((k, v) {
            if (v == null && insert)
                builder.set(_escape(k), 'DEFAULT');
            else
                builder.set(_escape(k), '@' + k).setParameter(k, v);
        });
        return builder;
    }

    Future<E> _onStreamRow(row) {
        Map data = row.toMap();
        String key = _cacheKeyFromData(data);
        Future<E> f = _cacheGet(key);
        return (f == null)? _cacheAdd(key, new Future.value(createObject(data))) : f;
    }

    Future<E> _streamToEntityFind(Stream stream) {
        return stream.map((row) => createObject(row.toMap()))
        .toList()
        .then((list) => (list.length > 0)? list[0] : null);
    }

    Future<E> _streamToEntity(Stream stream) {
        return stream.map(_onStreamRow)
        .toList()
        .then(Future.wait)
        .then((list) => (list.length > 0)? list[0] : null);
    }

    Future<C> _streamToCollection(Stream stream) {
        return stream.map(_onStreamRow)
        .toList()
        .then(Future.wait)
        .then((list) {
            C col = createCollection();
            col.addAll(list);
            return col;
        });
    }

    E _markObject(E object) {
        _ref[object.runtimeType.toString()] = this;
        return object;
    }

    String _cacheKeyFromData(Map data) {
        return (pkey is List)?
            pkey.map((k) => data[k]).join(_SEP) :
            data[pkey].toString();
    }

    Future<E> _cacheAdd(String k, Future<E> f) {
        manager.cacheAdd(this.runtimeType.toString() + k, f);
        return f;
    }

    Future<E> _cacheGet(String k) => manager.cacheGet(this.runtimeType.toString() + k);

    CollectionBuilder<E, C, A> collectionBuilder([Builder q]) {
        if (q == null)
            q = selectBuilder();
        return new CollectionBuilder(q, this);
    }

    _escape(String string) => '"$string"';

    E createObject([dynamic data]) {
        E object = entity()..manager = manager;
        if(data != null)
            object.init(data);
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