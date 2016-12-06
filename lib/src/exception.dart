part of mapper_server;

class QueryException implements Exception {

    PostgresqlException _e;

    String _q;

    Map _p;

    QueryException(this._e, this._q, this._p);

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