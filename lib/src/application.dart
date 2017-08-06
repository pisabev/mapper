part of mapper_server;

class Application {
  Manager<Application> m;

  Map<dynamic, dynamic> _data = new Map();

  Map _cache = new Map();

  set data(Map data) => _data = data;

  noSuchMethod(Invocation invocation) {
    var key = invocation.memberName;
    if (invocation.isGetter)
      return (_cache.containsKey(key))
          ? _cache[key]
          : _cache[key] = _data[key]()
        ..manager = m;
    super.noSuchMethod(invocation);
  }
}
