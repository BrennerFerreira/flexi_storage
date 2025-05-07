import 'cache_strategy.dart';

/// A simple LRU (Least Recently Used) cache strategy implementation.
/// This strategy is useful for caching data in memory with a limited size.
/// When the cache reaches its capacity, it removes the least recently used item.
class LRUCacheStrategy<K, V> extends CacheStrategy<K, V> {
  final int capacity;
  final _cache = <K, V>{};
  final _accessOrder = <K>[];

  LRUCacheStrategy(this.capacity);

  /// Get a value from the cache
  @override
  V? read(K key) {
    if (!_cache.containsKey(key)) return null;

    // Update access order
    _accessOrder.remove(key);
    _accessOrder.add(key);

    return _cache[key];
  }

  /// Write a value in the cache
  @override
  void write(K key, V value) {
    if (_cache.containsKey(key)) {
      _accessOrder.remove(key);
    } else if (_cache.length >= capacity) {
      // Remove least recently used item
      final lruKey = _accessOrder.removeAt(0);
      _cache.remove(lruKey);
    }

    _cache[key] = value;
    _accessOrder.add(key);
  }

  /// Check if the cache contains a key
  @override
  bool hasKey(K key) {
    return _cache.containsKey(key);
  }

  /// Remove a key from the cache
  @override
  void remove(K key) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
      _accessOrder.remove(key);
    }
  }
}
