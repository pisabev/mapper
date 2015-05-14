part of mapper_server;

class Connection {

    String _uri;

    int _min, _max;

    Pool _pool;

    Connection(this._uri, [this._min = 1, this._max = 5]) {
        _createPool();
        _pool.messages.listen((e) => log.warning(e.message));
    }

    _createPool() => _pool = new Pool(_uri,
        minConnections: _min,
        maxConnections: _max
        //leakDetectionThreshold: new Duration(seconds: 10),
        //restartIfAllConnectionsLeaked: true
    );

    Future start() => _pool.start();

    Future connect([String debugId]) {
        return _pool.connect(debugName: debugId)
        .catchError((e) => log.severe(e));
    }

}