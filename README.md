# flexi_storage

[![Pub Version](https://img.shields.io/pub/v/flexi_storage)](https://pub.dev/packages/flexi_storage)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Build Status](https://img.shields.io/github/actions/workflow/status/brennerferreira/flexi_storage/build.yml)](https://github.com/brennerferreira/flexi_storage/actions)

`flexi_storage` is a lightweight and flexible key-value storage solution for Flutter applications. It supports in-memory caching, optional encryption, and is designed to work seamlessly across web, mobile, and desktop platforms.

## Features

- 🗂️ Store, retrieve, and manage data using string keys.
- 🔒 Optional AES encryption for secure data storage.
- 🚀 In-memory caching with customizable strategies.
- 🔐 Thread-safe operations with document-level locking.
- 🌍 Cross-platform support (web, mobile, and desktop).
- 🛠️ Written in Dart, so no native code headaches!

## Installation

Add the following to your `pubspec.yaml` file:

```yaml
dependencies:
  flexi_storage: latest
```

Then run:

```bash
flutter pub get
```

## Getting Started

To quickly get started with `flexi_storage`, follow these steps:

1. Add the package to your `pubspec.yaml` file:

   ```yaml
   dependencies:
     flexi_storage: latest
   ```

2. Run the following command to fetch the package:

   ```bash
   flutter pub get
   ```

3. Import the package and initialize it in your Dart file:

   ```dart
   import 'package:flexi_storage/flexi_storage.dart';

   void main() async {
     final storage = FlexiStorage();
     await storage.init('/path/to/storage');
     print('Storage initialized');
   }
   ```

## Example App

For a complete example, check out the [example app](example/main.dart) included in this package. It demonstrates various features such as:

- Basic storage operations (write, read, remove, clear).
- Using encryption for secure data storage.
- Batch operations for grouped updates.

## Usage

### Basic Example

```dart
import 'package:flexi_storage/flexi_storage.dart';

void main() async {
  final storage = FlexiStorage();

  // Initialize storage
  await storage.init('/path/to/storage');

  // Write data
  await storage.write(docName: 'example', key: 'username', value: 'kiwify');

  // Read data
  final username = await storage.read<String>(docName: 'example', key: 'username');
  print(username); // Outputs: kiwify

  // Delete data
  await storage.remove(docName: 'example', key: 'username');

  // Clear document
  await storage.clearDocument('example');
}
```

### Encrypted Storage Example

```dart
await storage.write(
  docName: 'secureDoc',
  key: 'password',
  value: 'superSecret',
  encryptionPassword: 'myPassword',
);

final password = await storage.read<String>(
  docName: 'secureDoc',
  key: 'password',
  encryptionPassword: 'myPassword',
);
print(password); // Outputs: superSecret
```

## Cache Strategies

The `CacheStrategy` interface allows you to define how data is stored, retrieved, and managed in memory. This is useful for improving performance by avoiding frequent access to the underlying storage.

While it can significantly improve performance, it is not mandatory to use a cache strategy. If no cache strategy is provided, `FlexiStorage` will operate without in-memory caching.

You can use one of the provided cache strategies or create your own
strategy implementation.

### Provided Cache Strategies

The package includes the following cache strategies out of the box:

1. **LRUCacheStrategy**: Implements the Least Recently Used (LRU) eviction policy. When the cache reaches its capacity, the least recently used item is removed. Ideal for scenarios where frequently accessed data should remain in the cache.

2. **SizeLimitedCacheStrategy**: Limits the number of items stored in the cache. When the cache exceeds its maximum size, the oldest item (based on insertion order) is evicted. Suitable for memory-constrained environments.

3. **TimeBasedCacheStrategy**: Automatically removes items after a specified time-to-live (TTL). Useful for scenarios where data becomes stale after a certain period, such as caching API responses.

### Implementing a Custom Cache Strategy

To create a custom cache strategy, you need to implement the `CacheStrategy` interface. This allows you to define how data is stored, retrieved, and managed in the cache.

#### Example: Custom Cache Strategy

Here is an example of a custom cache strategy:

```dart
import 'dart:async';
import 'package:flexi_storage/src/cache/cache_strategy.dart';

class MyCustomCacheStrategy<K, V> implements CacheStrategy<K, V> {
  final Map<K, V> _cache = {};

  @override
  FutureOr<void> write(K key, V value) {
    _cache[key] = value;
  }

  @override
  FutureOr<V?> read(K key) {
    return _cache[key];
  }

  @override
  FutureOr<bool> hasKey(K key) {
    return _cache.containsKey(key);
  }

  @override
  FutureOr<void> remove(K key) {
    _cache.remove(key);
  }
}
```

#### Using the Custom Cache Strategy

Once you have implemented your custom cache strategy, you can use it with `FlexiStorage` as follows:

```dart
import 'package:flexi_storage/flexi_storage.dart';
import 'path/to/my_custom_cache_strategy.dart';

void main() async {
  final customCache = MyCustomCacheStrategy<String, Map<String, dynamic>>();
  final storage = FlexiStorage(cacheStrategy: customCache);

  await storage.init('/path/to/storage');

  // Use the storage as usual
  await storage.write(docName: 'example', key: 'key', value: 'value');
  final value = await storage.read<String>(docName: 'example', key: 'key');
  print(value); // Outputs: value
}
```

## API Overview

### Initialization

```dart
Future<void> init(String directoryPath);
```

Initializes the storage system. For web, the directory path is ignored.

### Writing Data

```dart
Future<void> write<T>({required String docName, required String key, required T value, String? encryptionPassword});
```

Writes a key-value pair to a document. Supports optional encryption.

### Reading Data

```dart
Future<T?> read<T>({required String docName, required String key, String? encryptionPassword});
```

Reads a value from a document. Returns `null` if the key does not exist.

### Removing Data

```dart
Future<void> remove({required String docName, required String key, String? encryptionPassword});
```

Removes a key-value pair from a document.

### Clearing a Document

```dart
Future<void> clearDocument(String docName);
```

Clears all data in a document.

### Deleting a Document

```dart
Future<void> deleteDocument(String docName, {String? encryptionPassword});
```

Deletes a document from storage.

### Batch Operations

Batch operations allow you to perform multiple operations on a document within a single batch. This is useful for grouping related operations together and ensuring they are executed atomically.

The `batch` method in `FlexiStorage` provides this functionality. Provide a function that takes a `BatchOperation` object, and all operations that should be performed.

#### Example Usage

```dart
await FlexiStorage.batch(
  docName: 'exampleDoc',
  operations: (batch) {
    batch.write('key1', 'value1');
    batch.write('key2', 42);
    batch.remove('key3');
  },
  encryptionPassword: 'securePassword',
);
```

In this example:

- The `batch` method ensures thread safety by locking the document during the operation.
- The `operations` function receives a `BatchOperation` object, which you can use to perform operations like `write`, `read`, `remove`, and `clear`.
- If the document is modified during the batch operation, it is automatically persisted.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
