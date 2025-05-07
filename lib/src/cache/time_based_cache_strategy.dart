import 'dart:async';
import 'cache_strategy.dart';

/// A cache strategy that automatically removes items after a specified time-to-live (TTL).
///
/// This strategy ensures that cached items are only valid for a limited duration.
/// Once the TTL expires, the item is removed from the cache.
///
/// Use Cases:
/// - Suitable for scenarios where data becomes stale after a certain period, such as caching API responses.
/// - Ideal for applications requiring automatic cache invalidation.
///
/// @param K The type of the cache key.
/// @param V The type of the cache value.
class TimeBasedCacheStrategy<K, V> implements CacheStrategy<K, V> {
  /// The time-to-live duration for cache entries.
  final Duration ttl;

  /// Internal map to store cache items.
  final Map<K, V> _cache = {};

  /// Map to track the expiration time of each cache entry.
  final Map<K, DateTime> _expiryTimes = {};

  /// Creates a new instance of [TimeBasedCacheStrategy].
  ///
  /// @param ttl The time-to-live duration for cache entries.
  TimeBasedCacheStrategy({required this.ttl});

  @override
  FutureOr<void> write(K key, V value) {
    _cache[key] = value;
    _expiryTimes[key] = DateTime.now().add(ttl);
  }

  @override
  FutureOr<V?> read(K key) {
    if (_expiryTimes[key]?.isAfter(DateTime.now()) ?? false) {
      return _cache[key];
    } else {
      _cache.remove(key);
      _expiryTimes.remove(key);
      return null;
    }
  }

  @override
  FutureOr<bool> hasKey(K key) {
    return _expiryTimes[key]?.isAfter(DateTime.now()) ?? false;
  }

  @override
  FutureOr<void> remove(K key) {
    _cache.remove(key);
    _expiryTimes.remove(key);
  }
}
