part of mapper_server;

class MapperException implements Exception {
  String message;

  String query;

  String params;

  drv.PostgreSQLException origException;

  MapperException(this.message, this.query, this.params, [this.origException]);

  String get details => query + ':\n' + params;

  String toString() => message;
}

class PostgreQueryException extends MapperException {
  PostgreQueryException(String m, String q, String p, drv.PostgreSQLException s)
      : super(m, q, p, s);
}

class PostgreConstraintException extends MapperException {
  PostgreConstraintException(String e, String q, String p, drv.PostgreSQLException s)
      : super(e, q, p, s);
}
