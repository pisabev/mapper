part of mapper_server;

class MapperException implements Exception {
  String message;

  String query;

  String params;

  ServerMessage serverMessage;

  MapperException(this.message, this.query, this.params, [this.serverMessage]);

  String toString() => message + ':\n' + query + ':\n' + params;
}

class PostgreQueryException extends MapperException {
  PostgreQueryException(String m, String q, String p, ServerMessage s)
      : super(m, q, p, s);
}

class PostgreConstraintException extends MapperException {
  PostgreConstraintException(String e, String q, String p, ServerMessage s)
      : super(e, q, p, s);
}
