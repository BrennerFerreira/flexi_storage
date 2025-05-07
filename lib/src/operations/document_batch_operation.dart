import 'package:flutter/foundation.dart';

import 'batch_operation.dart';

/// A class that implements the [BatchOperation] interface to perform
/// batch operations on a document represented as a `Map<String, dynamic>`.
///
/// This class provides methods to read, write, check for the existence of keys,
/// remove keys, and clear the document. It also tracks whether the document
/// has been modified during the batch operation.
///
/// Example usage:
/// ```dart
/// final document = {'key1': 'value1', 'key2': 42};
/// final batchOperation = DocumentBatchOperation(document);
///
/// batchOperation.write('key3', true);
/// print(batchOperation.read<bool>('key3')); // Output: true
/// print(batchOperation.modified); // Output: true
///
/// batchOperation.remove('key1');
/// print(batchOperation.hasKey('key1')); // Output: false
///
/// batchOperation.clear();
/// print(batchOperation.modified); // Output: true
/// print(document.isEmpty); // Output: true
/// ```
///
/// This class is useful for managing in-memory document storage with
/// batch operations and tracking changes.
class DocumentBatchOperation implements BatchOperation {
  final Map<String, dynamic> _document;
  bool _modified = false;

  bool get modified => _modified;

  DocumentBatchOperation(this._document);

  @override
  void write<T>(String key, T value) {
    _document[key] = value;
    _modified = true;
  }

  @override
  T? read<T>(String key) {
    if (!_document.containsKey(key)) return null;

    try {
      return _document[key] as T;
    } catch (e) {
      debugPrint('DocumentStorage: Type mismatch for key $key in batch operation');
      return null;
    }
  }

  @override
  bool hasKey(String key) {
    return _document.containsKey(key);
  }

  @override
  void remove(String key) {
    if (_document.containsKey(key)) {
      _document.remove(key);
      _modified = true;
    }
  }

  @override
  void clear() {
    if (_document.isEmpty) return;
    _document.clear();
    _modified = true;
  }
}
