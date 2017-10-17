part of mapper_server;

class MapperException implements Exception {
  String _m;

  String _q;

  Map _p;

  MapperException(this._m, this._q, this._p);

  String toString() => _m + ':\n' + _q + ':\n' + _p.toString();
}

class PostgreSQLException extends MapperException {

  PostgreSQLException(m, q, p) : super(m, q, p);

}

class ConstrainException extends MapperException {

  ConstrainException(e, q, p) : super(e, q, p);

}
