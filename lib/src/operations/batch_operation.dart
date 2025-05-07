/// An abstract class that defines a batch operation interface for managing
/// key-value pairs in a storage system. This class provides methods for
/// writing, reading, checking, removing, and clearing stored data.
abstract class BatchOperation {
  /// Writes a value of type [T] to the storage with the specified [key].
  ///
  /// - [key]: The unique identifier for the value to be stored.
  /// - [value]: The value to be stored, of type [T].
  void write<T>(String key, T value);

  /// Reads and returns a value of type [T] associated with the specified [key].
  ///
  /// - [key]: The unique identifier for the value to be retrieved.
  /// - Returns: The value of type [T] if the key exists, or `null` if the key
  ///   does not exist.
  T? read<T>(String key);

  /// Checks whether a value exists in the storage for the specified [key].
  ///
  /// - [key]: The unique identifier to check for existence.
  /// - Returns: `true` if the key exists, otherwise `false`.
  bool hasKey(String key);

  /// Removes the value associated with the specified [key] from the storage.
  ///
  /// - [key]: The unique identifier for the value to be removed.
  void remove(String key);

  /// Clears all key-value pairs from the storage.
  void clear();
}
