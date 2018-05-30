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
  final List<drv.PostgreSQLConnection> connectionsBusy = new List();

  int _inCreateProcess = 0;

  final List<Completer> _waitQueue = new List();

  Pool(this.host, this.port, this.database,
      [this.user, this.password, this._min = 1, this._max = 5]);

  Future start() async {
    for (int i = 0; i < _min; i++) {
      _inCreateProcess++;
      await _createConnection();
    }
  }

  Future destroy({bool graceful = true}) async {
    if(graceful) {
      if (connectionsBusy.isEmpty) {
        await new Future.delayed(new Duration(milliseconds: 5000));
        if (connectionsBusy.isEmpty) {
          await Future.wait(connections.map((conn) => conn.close()));
          return null;
        }
      }
      return new Future.delayed(new Duration(milliseconds: 20), destroy);
    } else {
      await Future.wait(connections.map((conn) => conn.close()));
    }
  }

  Future _createConnection() async {
    var conn = new drv.PostgreSQLConnection(host, port, database,
        username: user, password: password);
    await conn.open();
    _inCreateProcess--;
    connections.add(conn);
    _onConnectionReady(conn);
  }

  void _createProvide() {
    if (connectionsIdle.isNotEmpty)
      _onConnectionReady(connectionsIdle.first);
    else if (connections.length + _inCreateProcess < _max) {
      _inCreateProcess++;
      _createConnection();
    }
  }

  void _onConnectionReady(drv.PostgreSQLConnection conn) {
    if (conn.isClosed || conn.isInTransaction || conn.isInTransactionError) {
      connectionsIdle.remove(conn);
      connectionsBusy.remove(conn);
      connections.remove(conn);
      _createProvide();
    } else if (_waitQueue.isNotEmpty) {
      connectionsIdle.remove(conn);
      if (!connectionsBusy.contains(conn)) connectionsBusy.add(conn);
      _waitQueue.removeAt(0).complete(conn);
    } else {
      if (!connectionsIdle.contains(conn)) connectionsIdle.add(conn);
      connectionsBusy.remove(conn);
    }
  }

  void release(drv.PostgreSQLConnection conn) => _onConnectionReady(conn);
  Future<drv.PostgreSQLConnection> obtain({Duration timeout}) {
    var completer = new Completer();
    if (timeout != null) completer.future.timeout(timeout);
    _waitQueue.add(completer);

    _createProvide();

    return completer.future;
  }
}
