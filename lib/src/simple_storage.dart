import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:universal_web/web.dart' as web;

import 'cache/cache_strategy.dart';
import 'lock/storage_lock.dart';
import 'operations/batch_operation.dart';
import 'operations/document_batch_operation.dart';

/// The `SimpleStorage` class provides an abstraction for storing, retrieving,
/// and managing data in a simple key-value format. It is designed to be lightweight
/// and easy to use, making it suitable for scenarios where a full database solution
/// is not required.
///
/// ### Features:
/// - Store data using string keys.
/// - Retrieve data by key.
/// - Delete data by key.
/// - Clear all stored data.
///
/// ### Usage:
/// To use this class, create an instance of `SimpleStorage` and call its methods
/// to interact with the storage. Ensure that the storage backend (if any) is properly
/// initialized before using this class.
///
/// Provide a cache strategy in its constructor to manage in-memory caching.
/// There's a default cache strategy that uses LRU (Least Recently Used) caching.
/// If you want to use a different caching strategy, you can implement the
/// `CacheStrategy` interface and pass it to the `SimpleStorage` constructor.
///
/// ### Example:
/// ```dart
/// final storage = SimpleStorage();
/// storage.save('key', 'value');
/// final value = storage.get('key');
/// print(value); // Outputs: value
/// storage.delete('key');
/// ```
///
/// ### Notes:
/// - This class does not handle complex data structures directly. If you need to store
///   objects, serialize them to a string format (e.g., JSON) or a Map before saving.
/// - Ensure proper error handling when interacting with the storage to handle cases
///   like missing keys or storage failures.
class SimpleStorage {
  SimpleStorage({CacheStrategy<String, Map<String, dynamic>>? cacheStrategy}) : _documentsCache = cacheStrategy;

  // Directory path where files will be stored
  String? _basePath;

  // Flag to check if storage is initialized
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Cache strategy for in-memory caching
  final CacheStrategy<String, Map<String, dynamic>>? _documentsCache;

  // Document locks to prevent race conditions
  final _documentLocks = <String, StorageLock>{};

  /// Initializes the storage system with the given directory path.
  ///
  /// This method ensures that the storage system is properly set up before
  /// use. If the platform is web (`kIsWeb`), no directory path is required,
  /// and the initialization is completed immediately. For other platforms,
  /// it ensures that the specified directory exists, creating it if necessary.
  ///
  /// Multiple calls to this method is safe and will not re-initialize
  /// the storage system if it has already been initialized.
  ///
  /// [directoryPath] The path to the directory where the storage system
  /// should be initialized. This parameter is ignored on web platforms.
  ///
  /// Throws an exception if the directory cannot be created on non-web platforms.
  Future<void> init(String directoryPath) async {
    if (_isInitialized) return;

    if (kIsWeb) {
      // Web doesn't need a directory path
      _isInitialized = true;
    } else {
      // Ensure directory exists
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      _basePath = directoryPath;
      _isInitialized = true;
    }
  }

  /// Retrieves a `StorageLock` for the specified document name.
  ///
  /// If a lock for the given document name does not already exist, a new
  /// `StorageLock` is created and stored. This ensures that each document
  /// name has a unique lock associated with it.
  ///
  /// - Parameter docName: The name of the document for which the lock is needed.
  /// - Returns: The `StorageLock` associated with the specified document name.
  StorageLock _getLock(String docName) {
    if (!_documentLocks.containsKey(docName)) {
      _documentLocks[docName] = StorageLock();
    }
    return _documentLocks[docName]!;
  }

  /// Generates an encryption key from a given password.
  ///
  /// This method takes a password as input, encodes it to bytes using UTF-8,
  /// and then computes its SHA-256 hash. The resulting hash is converted into
  /// a hexadecimal string, which is used to create an encryption key.
  ///
  /// - Parameter password: The password string to generate the encryption key from.
  /// - Returns: An instance of [encrypt.Key] derived from the SHA-256 hash of the password.
  encrypt.Key _generateKeyFromPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return encrypt.Key.fromBase16(hash.toString());
  }

  /// Writes a value to a document in the storage.
  ///
  /// This method allows you to store a key-value pair in a specified document.
  /// If the document does not already contain the key, it will be added with
  /// the provided value. The document is persisted after the update.
  ///
  /// The operation is thread-safe and ensures that only one write operation
  /// can occur on the same document at a time.
  ///
  /// Type parameter:
  /// - [T]: The type of the value being stored.
  ///
  /// Parameters:
  /// - [docName]: The name of the document where the key-value pair will be stored.
  /// - [key]: The key under which the value will be stored.
  /// - [value]: The value to be stored in the document.
  /// - [encryptionPassword]: (Optional) A password used to encrypt the document.
  ///
  /// Throws:
  /// - An exception if the storage is not initialized.
  Future<void> write<T>({required String docName, required String key, required T value, String? encryptionPassword}) async {
    _checkInitialized();

    await _getLock(docName).synchronized(() async {
      final doc = await _loadDocument(docName: docName, encryptionPassword: encryptionPassword);
      doc.putIfAbsent(key, () => value);
      await _persistDocument(docName: docName, doc: doc, encryptionPassword: encryptionPassword);
    });
  }

  /// Reads a value of type `T` from the specified document.
  ///
  /// This method retrieves the value associated with the given [key] from the
  /// document identified by [docName]. If the document is encrypted, an
  /// optional [encryptionPassword] can be provided to decrypt it.
  ///
  /// If the [key] does not exist in the document, the method returns `null`.
  /// If the value exists but cannot be cast to the specified type `T`, a
  /// warning is logged, and `null` is returned.
  ///
  /// - [T]: The expected type of the value to be retrieved.
  /// - [docName]: The name of the document to read from.
  /// - [key]: The key whose associated value is to be retrieved.
  /// - [encryptionPassword]: (Optional) The password to decrypt the document, if encrypted.
  ///
  /// Returns the value of type `T` if it exists and matches the expected type,
  /// or `null` otherwise.
  ///
  /// Throws:
  /// - If the storage is not initialized, an exception is thrown.
  Future<T?> read<T>({required String docName, required String key, String? encryptionPassword}) async {
    _checkInitialized();

    final doc = await _loadDocument(docName: docName, encryptionPassword: encryptionPassword);
    if (!doc.containsKey(key)) return null;

    try {
      return doc[key] as T;
    } catch (e) {
      debugPrint('SimpleStorage: Type mismatch for key $key in doc $docName');
      return null;
    }
  }

  /// Removes a key-value pair from the specified document.
  ///
  /// This method ensures thread-safe access to the document by using a lock
  /// mechanism. It loads the document associated with the given [docName],
  /// removes the entry corresponding to the provided [key], and persists
  /// the updated document.
  ///
  /// Throws an exception if the storage is not initialized.
  ///
  /// Parameters:
  /// - [docName]: The name of the document from which the key-value pair
  ///   should be removed.
  /// - [key]: The key of the entry to be removed from the document.
  ///
  /// Example:
  /// ```dart
  /// await remove(docName: 'user_preferences', key: 'theme');
  /// ```
  Future<void> remove({required String docName, required String key, String? encryptionPassword}) async {
    _checkInitialized();

    await _getLock(docName).synchronized(() async {
      final doc = await _loadDocument(docName: docName, encryptionPassword: encryptionPassword);
      doc.remove(key);
      await _persistDocument(docName: docName, doc: doc, encryptionPassword: encryptionPassword);
    });
  }

  /// Clears the contents of a document with the specified name.
  ///
  /// This method ensures that the document is emptied and persisted with an
  /// empty map. It uses a lock mechanism to synchronize access to the document,
  /// ensuring thread safety during the operation.
  ///
  /// Throws an exception if the storage is not initialized.
  ///
  /// [docName] The name of the document to be cleared.
  ///
  /// Returns a [Future] that completes when the document has been cleared.
  Future<void> clearDocument(String docName) async {
    _checkInitialized();

    await _getLock(docName).synchronized(() async {
      final doc = <String, dynamic>{};
      await _persistDocument(docName: docName, doc: doc);
    });
  }

  /// Deletes a document with the specified [docName].
  ///
  /// This method ensures that the document is deleted both from the in-memory
  /// cache and the persistent storage. It uses a lock to synchronize access
  /// to the document, preventing race conditions during deletion.
  ///
  /// - If the document exists in the in-memory cache, it is removed.
  /// - On web platforms, the document is removed from the browser's local storage.
  /// - On non-web platforms, the document is deleted from the file system.
  ///
  /// Throws:
  /// - An exception if the storage is not initialized before calling this method.
  ///
  /// Parameters:
  /// - [docName]: The name of the document to be deleted.
  ///
  /// This method is asynchronous and should be awaited to ensure the deletion
  /// process completes before proceeding.
  Future<void> deleteDocument(String docName, {String? encryptionPassword}) async {
    _checkInitialized();

    await _getLock(docName).synchronized(() async {
      final hasKey = _documentsCache != null && await _documentsCache.hasKey(docName);
      if (hasKey) {
        _documentsCache.remove(docName);
      }

      final fileExtension = encryptionPassword != null ? '.txt' : '.json';

      if (kIsWeb) {
        web.window.localStorage.removeItem(docName);
      } else {
        final file = File('$_basePath/$docName$fileExtension');
        if (await file.exists()) {
          await file.delete();
        }
      }
    });
  }

  /// Retrieves a list of unique keys from the specified document.
  ///
  /// This method ensures that the storage system is initialized before
  /// attempting to load the document. It then fetches the document
  /// identified by [docName] and returns a list of all unique keys
  /// present in the document.
  ///
  /// [docName] - The name of the document from which to retrieve the keys.
  ///
  /// Returns a `Future` that resolves to a `List<String>` containing
  /// the unique keys in the document.
  ///
  /// Throws an exception if the storage system is not initialized or
  /// if the document cannot be loaded.
  Future<List<String>> getKeys(String docName) async {
    _checkInitialized();

    final doc = await _loadDocument(docName: docName);
    return doc.keys.toSet().toList();
  }

  /// Executes a batch operation on a document.
  ///
  /// This method allows you to perform multiple operations on a document
  /// within a single batch. The operations are executed within a synchronized
  /// block to ensure thread safety.
  ///
  /// If the document is modified during the batch operation, it will be
  /// persisted automatically.
  ///
  /// - [docName]: The name of the document to perform the batch operation on.
  /// - [operations]: A function that takes a [BatchOperation] object and
  ///   performs the desired operations on the document.
  /// - [encryptionPassword]: An optional password used to decrypt the document
  ///   if it is encrypted.
  ///
  /// Throws:
  /// - If the storage is not initialized, an exception will be thrown.
  ///
  /// Example:
  /// ```dart
  /// await simpleStorage.batch(
  ///   docName: 'exampleDoc',
  ///   operations: (batch) {
  ///     batch.put('key', 'value');
  ///     batch.delete('anotherKey');
  ///   },
  ///   encryptionPassword: 'securePassword',
  /// );
  /// ```
  Future<void> batch({required String docName, required FutureOr<dynamic> Function(BatchOperation) operations, String? encryptionPassword}) async {
    _checkInitialized();

    await _getLock(docName).synchronized(() async {
      final doc = await _loadDocument(docName: docName, encryptionPassword: encryptionPassword);
      final batchOp = DocumentBatchOperation(doc);

      await operations(batchOp);

      if (batchOp.modified) {
        await _persistDocument(docName: docName, doc: doc, encryptionPassword: encryptionPassword);
      }
    });
  }

  /// Checks if the SimpleStorage instance has been initialized.
  ///
  /// Throws a [StateError] if the instance is not initialized.
  /// Ensure that the `init()` method is called before invoking
  /// any other methods that depend on initialization.
  void _checkInitialized() {
    if (!_isInitialized) {
      throw StateError('SimpleStorage not initialized. Call init() first.');
    }
  }

  /// Loads a document from storage, either from cache, web storage, or the file system.
  ///
  /// This method first checks if the document is available in the cache. If found,
  /// it retrieves the cached data and returns it as a `Map<String, dynamic>`.
  ///
  /// If the document is not in the cache:
  /// - On web platforms, it attempts to load the document from the browser's
  ///   `localStorage`. If the document is found, it decodes and parses the data.
  /// - On non-web platforms, it attempts to load the document from the file system.
  ///   If the file exists, it reads, decodes, and parses the file contents.
  ///
  /// The method also supports optional decryption of the document using the
  /// provided [encryptionPassword].
  ///
  /// Once the document is successfully loaded, it is added to the cache for
  /// future access.
  ///
  /// If an error occurs during loading or decoding, the error is logged, and
  /// an empty document is returned.
  ///
  /// - [docName]: The name of the document to load.
  /// - [encryptionPassword]: An optional password for decrypting the document.
  ///
  /// Returns a `Future` that resolves to a `Map<String, dynamic>` containing
  /// the document data.
  Future<Map<String, dynamic>> _loadDocument({required String docName, String? encryptionPassword}) async {
    // Check if doc is in cache
    final hasKey = _documentsCache != null && await _documentsCache.hasKey(docName);
    if (hasKey) {
      final cache = await _documentsCache.read(docName);
      return Map<String, dynamic>.from(cache ?? {});
    }

    Map<String, dynamic> doc = {};

    if (kIsWeb) {
      // Web storage implementation
      final storedData = web.window.localStorage[docName];
      if (storedData != null && storedData.isNotEmpty) {
        try {
          final decodedData = _decodeDocument(docName, storedData, encryptionPassword);
          doc.addAll(jsonDecode(decodedData) as Map<String, dynamic>);
        } catch (e) {
          debugPrint('SimpleStorage: Error loading doc $docName: $e');
        }
      }
    } else {
      final fileExtension = encryptionPassword != null ? '.txt' : '.json';
      // File system implementation
      final file = File('$_basePath/$docName$fileExtension');
      final fileExists = await file.exists();

      if (fileExists) {
        try {
          final contents = await file.readAsString();
          if (contents.isNotEmpty) {
            final decodedContents = _decodeDocument(docName, contents, encryptionPassword);
            doc.addAll(jsonDecode(decodedContents) as Map<String, dynamic>);
          }
        } catch (e) {
          debugPrint('SimpleStorage: Error loading doc $docName: $e');
        }
      }
    }

    // Add to cache
    await _documentsCache?.write(docName, doc);
    return Map<String, dynamic>.from(doc);
  }

  /// Persists a document by saving it to the cache and then storing it either
  /// in the browser's local storage (for web) or the file system (for other platforms).
  ///
  /// This method first updates the in-memory cache with the provided document,
  /// then converts the document to a JSON string and optionally encrypts it
  /// before saving it to the appropriate storage medium.
  ///
  /// - For web platforms, the document is stored in the browser's local storage.
  /// - For non-web platforms, the document is saved as a `.json` file in the file system.
  ///
  /// The document can be optionally encrypted using the provided `encryptionPassword`.
  ///
  /// Parameters:
  /// - `docName` (required): The name of the document to be persisted.
  /// - `doc` (required): A map representing the document's data.
  /// - `encryptionPassword` (optional): A password used to encrypt the document.
  ///
  /// Throws:
  /// - Any exceptions that occur during file or storage operations.
  Future<void> _persistDocument({required String docName, required Map<String, dynamic> doc, String? encryptionPassword}) async {
    // Update cache
    await _documentsCache?.write(docName, Map<String, dynamic>.from(doc));

    // Convert to JSON
    final jsonString = jsonEncode(doc);
    final encodedData = _encodeDocument(docName: docName, data: jsonString, encryptionPassword: encryptionPassword);
    final fileExtension = encryptionPassword != null ? '.txt' : '.json';

    if (kIsWeb) {
      // Web storage implementation
      web.window.localStorage.setItem(docName, encodedData);
    } else {
      // File system implementation
      final file = File('$_basePath/$docName$fileExtension');
      await file.writeAsString(encodedData);
    }
  }

  /// Encodes a document by optionally encrypting its data.
  ///
  /// If an [encryptionPassword] is provided, the method encrypts the [data]
  /// using AES encryption with a key derived from the password and a fixed IV.
  /// The encrypted data is then returned as a base64-encoded string prefixed
  /// with 'ENCRYPTED:'. If no [encryptionPassword] is provided, the method
  /// returns the original [data] unmodified.
  ///
  /// - Parameters:
  ///   - [docName]: The name of the document being encoded (not used in the method).
  ///   - [data]: The content of the document to be encoded.
  ///   - [encryptionPassword]: An optional password used to encrypt the data.
  ///
  /// - Returns: A string containing either the encrypted data (if an
  ///   [encryptionPassword] is provided) or the original [data].
  String _encodeDocument({required String docName, required String data, String? encryptionPassword}) {
    if (encryptionPassword != null) {
      final key = _generateKeyFromPassword(encryptionPassword);
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final encrypted = encrypter.encrypt(data, iv: iv);

      final combined = '${iv.base64}:${encrypted.base64}';
      return 'ENCRYPTED:$combined';
    }
    return data;
  }

  /// Decodes a document string, optionally decrypting it if it is encrypted.
  ///
  /// This method checks if the provided `data` string starts with the prefix
  /// `'ENCRYPTED:'`. If so, and if an `encryptionPassword` is provided, it
  /// attempts to decrypt the data using AES encryption. If decryption fails,
  /// it logs an error and returns an empty JSON object (`'{}'`).
  ///
  /// If the data is not encrypted or no `encryptionPassword` is provided, the
  /// method simply returns the original `data`.
  ///
  /// - Parameters:
  ///   - docName: The name of the document being decoded. Used for logging purposes.
  ///   - data: The document data as a string, which may be encrypted.
  ///   - encryptionPassword: An optional password used to decrypt the data if it is encrypted.
  ///
  /// - Returns: The decoded document string. If decryption fails, returns `'{}'`.
  String _decodeDocument(String docName, String data, String? encryptionPassword) {
    if (data.startsWith('ENCRYPTED:') && encryptionPassword != null) {
      final encryptedData = data.substring(10);
      final parts = encryptedData.split(':');
      if (parts.length != 2) {
        debugPrint('SimpleStorage: Invalid format for encrypted doc $docName');
        return '{}';
      }

      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
      final key = _generateKeyFromPassword(encryptionPassword);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

      try {
        return encrypter.decrypt(encrypted, iv: iv);
      } catch (e) {
        debugPrint('SimpleStorage: Error decrypting doc $docName: $e');
        return '{}';
      }
    }
    return data;
  }
}
