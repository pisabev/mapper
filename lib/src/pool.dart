part of mapper_server;

class Pool {
  String host;
  int port;
  String database;
  String user;
  String password;
  String timeZone;
  bool autoClose;

  final int min, max;

  final List<drv.PostgreSQLConnection> connections = [];
  final List<drv.PostgreSQLConnection> connectionsIdle = [];
  final List<drv.PostgreSQLConnection> connectionsBusy = [];

  int _inCreateProcess = 0;

  final List<Completer> _waitQueue = [];

  Pool(this.host, this.port, this.database,
      {required this.user,
      required this.password,
      this.min = 1,
      this.max = 5,
      this.timeZone = 'UTC',
      this.autoClose = false});

  Future start() async {
    for (var i = 0; i < min; i++) await _createConnection();
  }

  Future destroy({bool graceful = true}) async {
    if (graceful) {
      if (connectionsBusy.isEmpty) {
        await new Future.delayed(const Duration(milliseconds: 5000));
        if (connectionsBusy.isEmpty) {
          await Future.wait(connections.map((conn) => conn.close()));
          return null;
        }
      }
      return new Future.delayed(const Duration(milliseconds: 20), destroy);
    } else {
      await Future.wait(connections.map((conn) => conn.close()));
    }
  }

  Future _createConnection() async {
    _inCreateProcess++;
    final conn = new drv.PostgreSQLConnection(host, port, database,
        username: user, password: password, timeZone: timeZone);
    await conn.open();
    _inCreateProcess--;
    connections.add(conn);
    _onConnectionReady(conn);
  }

  void _createProvide() {
    if (connectionsIdle.isNotEmpty)
      _onConnectionReady(connectionsIdle.first);
    else if (connections.length + _inCreateProcess < max) _createConnection();
  }

  // forceClose - a bug in connection as after the result is fetched
  // a stateChange is triggered to Idle and overriding the Close state.
  void _onConnectionReady(drv.PostgreSQLConnection conn) {
    if (conn.isClosed || conn.isInTransaction || autoClose) {
      connectionsIdle.remove(conn);
      connectionsBusy.remove(conn);
      connections.remove(conn);
      conn.close();
      if (connections.length + _inCreateProcess < min) _createConnection();
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

  Future<drv.PostgreSQLConnection> obtain({Duration? timeout}) {
    final completer = new Completer<drv.PostgreSQLConnection>();
    if (timeout != null) completer.future.timeout(timeout);
    _waitQueue.add(completer);

    _createProvide();

    return completer.future;
  }
}
