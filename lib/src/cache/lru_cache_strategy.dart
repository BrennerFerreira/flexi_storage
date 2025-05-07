import 'cache_strategy.dart';

/// A cache strategy that implements the Least Recently Used (LRU) eviction policy.
///
/// This strategy ensures that when the cache reaches its capacity, the least recently used item is removed.
/// It is useful for caching data in memory with a limited size while prioritizing frequently accessed items.
///
/// Use Cases:
/// - Suitable for scenarios where frequently accessed data should remain in the cache.
/// - Ideal for caching results of expensive computations or database queries.
///
/// @param K The type of the cache key.
/// @param V The type of the cache value.
class LRUCacheStrategy<K, V> extends CacheStrategy<K, V> {
  /// The maximum number of items the cache can hold.
  final int capacity;

  /// Internal map to store cache items.
  final Map<K, V> _cache = <K, V>{};

  /// List to track the order of key accesses.
  final List<K> _accessOrder = <K>[];

  /// Creates a new instance of [LRUCacheStrategy].
  ///
  /// @param capacity The maximum number of items the cache can hold.
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
      final K lruKey = _accessOrder.removeAt(0);
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
