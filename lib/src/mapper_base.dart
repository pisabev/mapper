part of mapper_server;

abstract class MapperBase<E extends Entity<Application>,
    C extends Collection<E>, A extends Application> {
  final Manager<A> manager;

  EntityFunction<E> entity;

  EntityFunction<C> collection;

  MapperBase(this.manager);

  Builder queryBuilder() => new Builder();

  Future<E> loadE(Builder builder) => _streamToEntity(builder)
      .catchError((e) => manager._error(e, builder.getSQL(), builder._params));

  Future<C> loadC(Builder builder, [bool calcTotal = false]) =>
      _streamToCollection(builder, calcTotal).catchError(
          (e) => manager._error(e, builder.getSQL(), builder._params));

  E _onStreamRow(data) => createObject(data);

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

  CollectionBuilder<E, C, A> collectionBuilder([Builder q]) {
    q ??= queryBuilder();
    return new CollectionBuilder<E, C, A>(q, this);
  }

  E createObject([Map data]) => entity()..init(data);

  C createCollection() => collection();
}
