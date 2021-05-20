part of mapper_server;

typedef EntityFunction<T> = T Function();

abstract class MapperBase<E extends Entity, C extends Collection<E>> {
  final Manager manager;

  late EntityFunction<E> entity;

  late EntityFunction<C> collection;

  MapperBase(this.manager);

  Future<E> loadE(Builder builder) => _streamToEntity(builder)
      .catchError((e) => manager._error(e, builder.getSQL(), builder._params));

  Future<C> loadC(Builder builder, [bool calcTotal = false]) =>
      _streamToCollection(builder, calcTotal).catchError(
          (e) => manager._error(e, builder.getSQL(), builder._params));

  E _onStreamRow(data) => createObject(data);

  Future<List> execute(Builder builder) => manager._connection!
      .query(builder.getSQL(), substitutionValues: builder._params)
      .catchError((e) => manager._error(e, builder.getSQL(), builder._params));

  Future<E> _streamToEntity(Builder builder) async {
    final res = await manager._connection!
        .queryToEntityCollection(
            builder.getSQL(), _onStreamRow, createCollection(),
            substitutionValues: builder._params)
        .catchError(
            (e) => manager._error(e, builder.getSQL(), builder._params));
    return res.isEmpty ? null : res.first;
  }

  Future<C> _streamToCollection(Builder builder, [calcTotal = false]) async {
    if (calcTotal) builder.addSelect('COUNT(*) OVER() AS __total__');
    return manager._connection!.queryToEntityCollection(
        builder.getSQL(), _onStreamRow, createCollection(),
        substitutionValues: builder._params);
  }

  Future<C> queryToEntityCollection(
          String query, Map<String, dynamic> params) async =>
      manager._connection!.queryToEntityCollection(
          query, _onStreamRow, createCollection(),
          substitutionValues: params);

  CollectionBuilder<E, C> collectionBuilder([Builder? q]) {
    q ??= new Builder();
    return new CollectionBuilder<E, C>(q, this);
  }

  E createObject([dynamic data]) {
    final object = entity().._mapper = this;
    if (data != null) object.init(data);
    return object;
  }

  C createCollection() => collection();
}
