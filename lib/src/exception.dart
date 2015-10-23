part of mapper_server;

class TransactionStartedException implements Exception {

    String _msg = 'Transaction already started';

    TransactionStartedException();

    String toString() => _msg;

}

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

    String _q;

    Map _p;

    ConstrainException(this._e, this._q, this._p);

    String get code => _e.serverMessage.code;

    String get severity => _e.serverMessage.severity;

    String toString() => _e.toString() + ':\n' + _q + ':\n' + _p.toString();

}