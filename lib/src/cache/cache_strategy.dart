import 'dart:async';

abstract class CacheStrategy<K, V> {
  /// Writes a value to the cache with the given key.
  FutureOr<void> write(K key, V value);

  /// Reads a value from the cache with the given key.
  FutureOr<V?> read(K key);

  /// Checks if a key exists in the cache.
  FutureOr<bool> hasKey(K key);

  /// Removes a value from the cache with the given key.
  FutureOr<void> remove(K key);
}
