import 'dart:async';

/// A class that provides locking mechanisms for storage operations.
///
/// The `StorageLock` class is designed to ensure thread-safe access to
/// shared storage resources. It can be used to prevent race conditions
/// and ensure data consistency when multiple operations are performed
/// concurrently.
///
/// This class can be particularly useful in scenarios where multiple
/// asynchronous tasks need to access or modify the same storage resource.
class StorageLock {
  Completer<void>? _completer;

  /// Executes the given asynchronous [action] in a synchronized manner, ensuring
  /// that only one operation can be performed at a time.
  ///
  /// If another operation is already in progress, this method will wait for it
  /// to complete before executing the provided [action].
  ///
  /// The [action] is a function that returns a [Future] of type [T], representing
  /// the result of the operation.
  ///
  /// Returns a [Future] of type [T] that completes with the result of the [action].
  ///
  /// Example usage:
  /// ```dart
  /// final result = await synchronized(() async {
  ///   // Perform some asynchronous operation
  ///   return await someAsyncFunction();
  /// });
  /// ```
  ///
  /// This method ensures thread safety by using a [Completer] to manage the
  /// synchronization of operations.
  Future<T> synchronized<T>(Future<T> Function() action) async {
    // Wait for any existing operation to complete
    if (_completer != null) {
      await _completer!.future;
    }

    // Create a new completer for this operation
    _completer = Completer<void>();

    try {
      // Perform the action
      final result = await action();
      return result;
    } finally {
      // Release the lock
      final completer = _completer!;
      _completer = null;
      completer.complete();
    }
  }
}
