import 'dart:async';
import 'cache_strategy.dart';

/// A cache strategy that limits the number of items stored in the cache.
///
/// This strategy ensures that the cache does not exceed a specified maximum size.
/// When the cache reaches its capacity, it evicts the oldest item (based on insertion order).
///
/// Use Cases:
/// - Suitable for memory-constrained environments where the cache size must be controlled.
/// - Ideal for scenarios where the order of insertion is more important than usage frequency.
///
/// @param K The type of the cache key.
/// @param V The type of the cache value.
class SizeLimitedCacheStrategy<K, V> implements CacheStrategy<K, V> {
  /// The maximum number of items the cache can hold.
  final int maxSize;

  /// Internal map to store cache items.
  final Map<K, V> _cache = <K, V>{};

  /// List to track the order of key insertions.
  final List<K> _accessOrder = <K>[];

  /// Creates a new instance of [SizeLimitedCacheStrategy].
  ///
  /// @param maxSize The maximum number of items the cache can hold.
  SizeLimitedCacheStrategy({required this.maxSize});

  @override
  FutureOr<void> write(K key, V value) {
    if (_cache.length >= maxSize) {
      final K oldestKey = _accessOrder.removeAt(0);
      _cache.remove(oldestKey);
    }
    _cache[key] = value;
    _accessOrder.remove(key);
    _accessOrder.add(key);
  }

  @override
  FutureOr<V?> read(K key) {
    if (_cache.containsKey(key)) {
      _accessOrder.remove(key);
      _accessOrder.add(key);
      return _cache[key];
    }
    return null;
  }

  @override
  FutureOr<bool> hasKey(K key) {
    return _cache.containsKey(key);
  }

  @override
  FutureOr<void> remove(K key) {
    _cache.remove(key);
    _accessOrder.remove(key);
  }
}
