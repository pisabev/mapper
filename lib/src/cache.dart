part of mapper_server;

class Cache {
  final Map<String, Entity?> _cache = {};
  final Map<String, Map?> _cache_init = {};

  void add(String key, Entity object, Map? initData) {
    _cache[key] = object;
    if (initData != null) _cache_init[key] = initData;
  }

  void delete(String key) {
    _cache[key] = null;
    if (_cache_init.containsKey(key)) _cache_init[key] = null;
  }

  Entity? get(String key) => (_cache.containsKey(key)) ? _cache[key] : null;

  Map? getInitData(String key) =>
      (_cache_init.containsKey(key)) ? _cache_init[key] : null;

  String toString() => _cache.toString();
}
