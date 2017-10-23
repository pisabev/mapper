part of mapper_server;

class Pool {
  String host;
  int port;
  String database;
  String user;
  String password;

  int _min, _max;

  final List<drv.PostgreSQLConnection> connections = new List();
  final List<drv.PostgreSQLConnection> connectionsIdle = new List();

  int _inCreateProcess = 0;

  final List<Completer> _waitQueue = new List();

  Pool(this.host, this.port, this.database, [this.user, this.password, this._min = 1, this._max = 5]);

  Future start() async {
    for (int i = 0; i < _min; i++) {
      _inCreateProcess++;
      await _createConnection();
    }
  }

  close(drv.PostgreSQLConnection conn) {}

  Future _createConnection() async {
    var conn = new drv.PostgreSQLConnection(host, port, database, username: user, password: password);
    await conn.open();
    _inCreateProcess--;
    connections.add(conn);
    _onConnectionReady(conn);
  }

  _onConnectionReady(drv.PostgreSQLConnection conn) {
    if (conn.isClosed) {
      connectionsIdle.remove(conn);
      connections.remove(conn);
      return;
    }
    if (_waitQueue.isNotEmpty) {
      connectionsIdle.remove(conn);
      _waitQueue.removeAt(0).complete(conn);
    } else {
      connectionsIdle.add(conn);
    }
  }

  release(drv.PostgreSQLConnection conn) => _onConnectionReady(conn);

  Future<drv.PostgreSQLConnection> obtain({Duration timeout}) {
    var completer = new Completer();
    if(timeout != null)
      completer.future.timeout(timeout);
    _waitQueue.add(completer);

    if (connectionsIdle.isNotEmpty && _waitQueue.length == 1)
      _onConnectionReady(connectionsIdle.first);
    else if (connections.length + _inCreateProcess < _max) {
      _inCreateProcess++;
      _createConnection();
    }

    return completer.future;
  }
}
