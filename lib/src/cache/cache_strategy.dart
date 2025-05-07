import 'dart:async';

/// An abstract class defining the interface for cache strategies.
///
/// This class provides the basic operations required for any caching mechanism, such as writing,
/// reading, checking the existence of, and removing cached values. Specific caching strategies
/// can extend this class to implement their own behavior.
///
/// Use Cases:
/// - Provides a common interface for implementing various caching strategies.
/// - Allows flexibility in choosing or switching between different caching mechanisms.
///
/// @param K The type of the cache key.
/// @param V The type of the cache value.
abstract class CacheStrategy<K, V> {
  /// Writes a value to the cache with the given key.
  ///
  /// @param key The key associated with the value to be cached.
  /// @param value The value to be stored in the cache.
  /// @throws Any implementation-specific exceptions if the write operation fails.
  FutureOr<void> write(K key, V value);

  /// Reads a value from the cache with the given key.
  ///
  /// @param key The key associated with the value to be retrieved.
  /// @return The value associated with the key, or null if the key does not exist or has expired.
  FutureOr<V?> read(K key);

  /// Checks if a key exists in the cache.
  ///
  /// @param key The key to check for existence in the cache.
  /// @return True if the key exists in the cache, false otherwise.
  FutureOr<bool> hasKey(K key);

  /// Removes a value from the cache with the given key.
  ///
  /// @param key The key associated with the value to be removed.
  /// @throws Any implementation-specific exceptions if the remove operation fails.
  FutureOr<void> remove(K key);
}
