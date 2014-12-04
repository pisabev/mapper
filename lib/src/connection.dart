part of mapper_server;

class Connection {

    String _uri;

    int _min, _max;

    Pool _pool;

    Connection(this._uri, [this._min = 1, this._max = 5]) {
        _createPool();
    }

    _createPool() => _pool = new Pool(_uri,
        minConnections: 1,
        maxConnections: 4,
        idleTimeout: new Duration(seconds: 15));

    Future start() => _pool.start();

    Future connect() {
        return _pool.connect()
        .timeout(new Duration(milliseconds:5000), onTimeout:() {
            _pool.stop()
            .then((_) {
                _createPool();
                log.warning('pool destroyed (probably connections leak)');
                return start().then((_) => connect());
            });
        })
        .catchError((e) => log.severe(e));
    }

}