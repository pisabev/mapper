part of mapper_server;

class Cache {
  Map<String, Future<Entity>> _cache = new Map();

  add(String key, Future<Entity> object) => _cache[key] = object;

  Future<Entity> get(String key) =>
      (_cache.containsKey(key)) ? _cache[key] : null;

  toString() => _cache.toString();
}
