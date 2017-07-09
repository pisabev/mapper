part of mapper_server;

class Cache {
  final Map<String, Future<Entity>> _cache = new Map<String, Future<Entity>>();

  add(String key, Future<Entity> object) => _cache[key] = object;

  Future<Entity> get(String key) => _cache.containsKey(key) ? _cache[key] : null;

  String toString() => _cache.toString();
}
