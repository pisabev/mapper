part of mapper_server;

class PostgreSQLException implements Exception {
  PostgresqlException _e;

  String _q;

  Map _p;

  PostgreSQLException(this._e, this._q, this._p);

  String get code => _e.serverMessage.code;

  String get severity => _e.serverMessage.severity;

  String toString() => _e.toString() + ':\n' + _q + ':\n' + _p.toString();
}

class ConstrainException implements Exception {
  PostgresqlException _e;

  ConstrainException(this._e);

  String get code => _e.serverMessage.code;

  String get severity => _e.serverMessage.severity;

  String toString() => _e.message.toString();
}

class RandomException implements Exception {
  Exception _e;

  String _q;

  Map _p;

  RandomException(this._e, this._q, this._p);

  String toString() => _e.toString() + ':\n' + _q + ':\n' + _p.toString();
}
