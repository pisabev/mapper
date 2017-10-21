part of mapper_server;

class Pool {
  String _uri;

  int _min, _max;

  final List<drv.Connection> connections = new List();
  final List<drv.Connection> connectionsIdle = new List();

  int _inCreateProcess = 0;

  final List<Completer> _waitQueue = new List();

  Pool(this._uri, [this._min = 1, this._max = 5]);

  Future start() async {
    for (int i = 0; i < _min; i++) {
      _inCreateProcess++;
      await _createConnection();
    }
  }

  close(drv.Connection conn) {}

  Future _createConnection() async {
    var conn = await drv.connect(_uri);
    _inCreateProcess--;
    connections.add(conn);
    _onConnectionReady(conn);
  }

  _onConnectionReady(drv.Connection conn) {
    if (_waitQueue.isNotEmpty) {
      connectionsIdle.remove(conn);
      _waitQueue.removeAt(0).complete(conn);
    } else {
      connectionsIdle.add(conn);
    }
  }

  release(drv.Connection conn) => _onConnectionReady(conn);

  Future<drv.Connection> obtain({Duration timeout}) {
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
