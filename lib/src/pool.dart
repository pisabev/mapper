part of mapper_server;

class Pool {
  final String host;
  final int port;
  final String database;
  final String user;
  final String password;
  final String timeZone;
  final bool autoClose;
  final Duration? clearIdleAfter;
  final Map<int, Timer> _idleTimer = {};

  final int min, max;

  final Set<drv.PostgreSQLConnection> connections = {};
  final Set<drv.PostgreSQLConnection> connectionsIdle = {};
  final Set<drv.PostgreSQLConnection> connectionsBusy = {};

  int _inCreateProcess = 0;

  final List<Completer> _waitQueue = [];

  Pool(this.host, this.port, this.database,
      {required this.user,
      required this.password,
      this.min = 1,
      this.max = 5,
      this.timeZone = 'UTC',
      this.autoClose = false,
      this.clearIdleAfter});

  Future start() async {
    await _createConnection();
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
    if (connections.length + _inCreateProcess < max) {
      _inCreateProcess++;
      final conn = new drv.PostgreSQLConnection(host, port, database,
          username: user, password: password, timeZone: timeZone);
      await conn.open();
      _inCreateProcess--;
      connections.add(conn);
      _onConnectionReady(conn);
      await _createConnection();
    }
  }

  void _onConnectionReady(drv.PostgreSQLConnection conn,
      [bool terminate = false]) {
    if (terminate || conn.isClosed || conn.isInTransaction)
      _connectionTerminate(conn);
    else if (_waitQueue.isNotEmpty)
      _serveConnection(conn);
    else
      _cacheConnection(conn);
  }

  void _serveConnection(drv.PostgreSQLConnection conn) {
    _clearIdleTimer(conn);
    connectionsIdle.remove(conn);
    connectionsBusy.add(conn);
    _waitQueue.removeAt(0).complete(conn);
  }

  void _cacheConnection(drv.PostgreSQLConnection conn) {
    connectionsBusy.remove(conn);
    connectionsIdle.add(conn);
    if (clearIdleAfter != null)
      _idleTimer[conn.processID!] =
          new Timer(clearIdleAfter!, () => _connectionTerminate(conn));
  }

  void _clearIdleTimer(drv.PostgreSQLConnection conn) {
    if (clearIdleAfter == null) return;
    _idleTimer[conn.processID!]?.cancel();
    _idleTimer.remove(conn.processID);
  }

  void _connectionTerminate(drv.PostgreSQLConnection conn) {
    _clearIdleTimer(conn);
    connectionsIdle.remove(conn);
    connectionsBusy.remove(conn);
    connections.remove(conn);
    conn.close();
    _createConnection();
  }

  void release(drv.PostgreSQLConnection conn) =>
      _onConnectionReady(conn, autoClose);

  Future<drv.PostgreSQLConnection> obtain({Duration? timeout}) {
    final completer = new Completer<drv.PostgreSQLConnection>();
    if (timeout != null) completer.future.timeout(timeout);
    _waitQueue.add(completer);

    if (connectionsIdle.isNotEmpty) _onConnectionReady(connectionsIdle.first);

    return completer.future;
  }
}
