import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'dart:io';
import 'package:simple_storage/src/simple_storage.dart';
import 'package:simple_storage/src/utils/file_handler.dart';
import 'package:simple_storage/src/utils/is_web_util.dart';

import 'simple_storage_test.mocks.dart';

@GenerateNiceMocks([MockSpec<Directory>(), MockSpec<File>()])
void main() {
  late SimpleStorage storage;
  late MockDirectory mockDirectory;
  late MockFile mockFile;

  const path = 'test_path';
  const docName = 'testDoc';
  const key = 'testKey';
  const value = 'testValue';
  const encryptionPassword = 'securePassword';

  setUp(() async {
    storage = SimpleStorage();
    mockDirectory = MockDirectory();
    mockFile = MockFile();

    when(mockDirectory.path).thenReturn(path);
    when(mockDirectory.exists()).thenAnswer((_) async => true);
    when(mockDirectory.create(recursive: true)).thenAnswer((_) async => mockDirectory);

    when(mockFile.exists()).thenAnswer((_) async => true);
    when(mockFile.create(recursive: true)).thenAnswer((_) async => mockFile);
    when(mockFile.writeAsString(captureAny)).thenAnswer((inv) async => mockFile);
    when(mockFile.delete()).thenAnswer((_) async => mockFile);

    FileHandler.mockDirectory = mockDirectory; // Set the mock directory
    FileHandler.mockFile = mockFile;
  });

  tearDown(() async {
    IsWebUtil.override = false; // Reset web override
    FileHandler.mockDirectory = null; // Reset mock directory
    FileHandler.mockFile = null; // Reset mock file
  });

  group("SimpleStorage", () {
    group('init', () {
      test('should initialize on web platform', () async {
        IsWebUtil.override = true; // Simulate web
        expect(storage.isInitialized, isFalse);

        await storage.init('');

        expect(storage.isInitialized, isTrue);
        verifyZeroInteractions(mockDirectory);
      });

      test('should initialize and create directory on non-web platform', () async {
        when(mockDirectory.exists()).thenAnswer((_) async => false);
        when(mockDirectory.create(recursive: true)).thenAnswer((_) async => mockDirectory);

        expect(storage.isInitialized, isFalse);

        await storage.init(path);

        expect(storage.isInitialized, isTrue);
        verify(mockDirectory.create(recursive: true)).called(1);
      });

      test('should not reinitialize if already initialized', () async {
        when(mockDirectory.exists()).thenAnswer((_) async => false);
        when(mockDirectory.create(recursive: true)).thenAnswer((_) async => mockDirectory);
        when(mockDirectory.exists()).thenAnswer((_) async => true);

        await storage.init(path);
        expect(storage.isInitialized, isTrue);

        await storage.init(path);
        verifyNever(mockDirectory.create(recursive: true));
      });

      test('should throw exception if directory cannot be created', () async {
        FileHandler.mockDirectory = mockDirectory;
        when(mockDirectory.exists()).thenAnswer((_) async => false);
        when(mockDirectory.create(recursive: true)).thenThrow(FileSystemException('Failed to create directory'));

        expect(() async => await storage.init(path), throwsA(isA<FileSystemException>()));
      });
    });

    group('write', () {
      test('should write a key-value pair to a document', () async {
        await storage.init(path);

        when(mockFile.readAsString()).thenAnswer((_) async => '{}');
        await storage.write(docName: docName, key: key, value: value);

        verify(mockFile.writeAsString(jsonEncode({key: value}))).called(1);
      });

      test('should overwrite an existing key with a new value', () async {
        const initialValue = 'initialValue';
        const newValue = 'newValue';

        when(mockFile.readAsString()).thenAnswer((_) async => '{}');

        await storage.init(path);
        await storage.write(docName: docName, key: key, value: initialValue);
        await storage.write(docName: docName, key: key, value: newValue);

        verify(mockFile.writeAsString(jsonEncode({key: initialValue}))).called(1);
        verify(mockFile.writeAsString(jsonEncode({key: newValue}))).called(1);
      });

      test('should throw an exception if storage is not initialized', () async {
        when(mockFile.readAsString()).thenAnswer((_) async => '{}');
        expect(() async => await storage.write(docName: docName, key: key, value: value), throwsA(isA<StateError>()));
      });

      test('should write an encrypted document if encryptionPassword is provided', () async {
        when(mockFile.readAsString()).thenAnswer((_) async => '{}');
        const encryptionPassword = 'securePassword';

        await storage.init(path);
        await storage.write(docName: docName, key: key, value: value, encryptionPassword: encryptionPassword);

        final capturedCall = verify(mockFile.writeAsString(captureAny));
        expect(capturedCall.captured.length, 1);
        final encryptedData = capturedCall.captured[0] as String;
        expect(encryptedData, isA<String>());
        expect(encryptedData.startsWith('ENCRYPTED:'), isTrue);
      });
    });

    group('read', () {
      test('should read a value by key from a document', () async {
        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => jsonEncode({key: value}));

        final result = await storage.read<String>(docName: docName, key: key);

        expect(result, equals(value));
      });

      test('should return null if key does not exist in the document', () async {
        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => jsonEncode({}));

        final result = await storage.read<String>(docName: docName, key: key);

        expect(result, isNull);
      });

      test('should throw an exception if storage is not initialized', () async {
        expect(() async => await storage.read<String>(docName: docName, key: key), throwsA(isA<StateError>()));
      });

      test('should read an encrypted value if encryptionPassword is provided', () async {
        final jsonData = jsonEncode({key: value});
        final encryptedData = storage.encodeDocument(docName: docName, data: jsonData, encryptionPassword: encryptionPassword);

        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => encryptedData);

        final result = await storage.read<String>(docName: docName, key: key, encryptionPassword: encryptionPassword);

        expect(result, equals(value));
      });

      test('should return null if type mismatch occurs', () async {
        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => jsonEncode({key: value}));

        final result = await storage.read<int>(docName: docName, key: key);

        expect(result, isNull);
      });
    });

    group('remove', () {
      test('should remove a key-value pair from a document', () async {
        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => jsonEncode({key: value}));

        await storage.remove(docName: docName, key: key);

        verify(mockFile.writeAsString(jsonEncode({}))).called(1);
      });

      test('should throw an exception if storage is not initialized', () async {
        expect(() async => await storage.remove(docName: docName, key: key), throwsA(isA<StateError>()));
      });

      test('should remove an encrypted key-value pair if encryptionPassword is provided', () async {
        final jsonData = jsonEncode({key: value});
        final encryptedData = storage.encodeDocument(docName: docName, data: jsonData, encryptionPassword: encryptionPassword);

        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => encryptedData);

        await storage.remove(docName: docName, key: key, encryptionPassword: encryptionPassword);
        final capturedWrite = verify(mockFile.writeAsString(captureAny));
        final decryptedData = storage.decodeDocument(docName, capturedWrite.captured[0], encryptionPassword);
        expect(decryptedData, equals(jsonEncode({})));
      });
    });

    group('clearDocument', () {
      test('should clear the contents of a document', () async {
        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => jsonEncode({key: value}));

        await storage.clearDocument(docName);

        verify(mockFile.writeAsString(jsonEncode({}))).called(1);
      });

      test('should throw an exception if storage is not initialized', () async {
        expect(() async => await storage.clearDocument(docName), throwsA(isA<StateError>()));
      });

      test('should clear an encrypted document if encryptionPassword is provided', () async {
        final jsonData = jsonEncode({key: value});
        final encryptedData = storage.encodeDocument(docName: docName, data: jsonData, encryptionPassword: encryptionPassword);

        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => encryptedData);

        await storage.clearDocument(docName);
        final capturedWrite = verify(mockFile.writeAsString(captureAny));
        final decryptedData = storage.decodeDocument(docName, capturedWrite.captured[0], encryptionPassword);
        expect(decryptedData, equals(jsonEncode({})));
      });
    });

    group('deleteDocument', () {
      test('should delete a document from storage', () async {
        await storage.init(path);
        when(mockFile.exists()).thenAnswer((_) async => true);

        await storage.deleteDocument(docName);

        verify(mockFile.delete()).called(1);
      });

      test('should throw an exception if storage is not initialized', () async {
        expect(() async => await storage.deleteDocument(docName), throwsA(isA<StateError>()));
      });

      test('should delete an encrypted document if encryptionPassword is provided', () async {
        final jsonData = jsonEncode({key: value});
        final encryptedData = storage.encodeDocument(docName: docName, data: jsonData, encryptionPassword: encryptionPassword);

        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => encryptedData);
        when(mockFile.exists()).thenAnswer((_) async => true);

        await storage.deleteDocument(docName, encryptionPassword: encryptionPassword);

        verify(mockFile.delete()).called(1);
      });
    });

    group('getKeys', () {
      test('should return all keys from a document', () async {
        await storage.init(path);
        final documentData = {key: value, 'anotherKey': 'anotherValue'};
        when(mockFile.readAsString()).thenAnswer((_) async => jsonEncode(documentData));

        final keys = await storage.getKeys(docName);

        expect(keys, containsAll(documentData.keys));
      });

      test('should return an empty list if the document is empty', () async {
        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => jsonEncode({}));

        final keys = await storage.getKeys(docName);

        expect(keys, isEmpty);
      });

      test('should throw an exception if storage is not initialized', () async {
        expect(() async => await storage.getKeys(docName), throwsA(isA<StateError>()));
      });

      test('should return keys from an encrypted document if encryptionPassword is provided', () async {
        final documentData = {key: value, 'anotherKey': 'anotherValue'};
        final jsonData = jsonEncode(documentData);
        final encryptedData = storage.encodeDocument(docName: docName, data: jsonData, encryptionPassword: encryptionPassword);

        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => encryptedData);

        final keys = await storage.getKeys(docName, encryptionPassword: encryptionPassword);

        expect(keys, containsAll(documentData.keys));
      });
    });

    group('batch', () {
      test('should perform batch operations on a document', () async {
        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => jsonEncode({key: value}));

        await storage.batch(
          docName: docName,
          operations: (batch) {
            batch.write('newKey', 'newValue');
            batch.remove(key);
          },
        );

        final capturedWrite = verify(mockFile.writeAsString(captureAny)).captured.single;
        final updatedDocument = jsonDecode(capturedWrite) as Map<String, dynamic>;

        expect(updatedDocument.containsKey('newKey'), isTrue);
        expect(updatedDocument['newKey'], equals('newValue'));
        expect(updatedDocument.containsKey(key), isFalse);
      });

      test('should throw an exception if storage is not initialized', () async {
        expect(() async => await storage.batch(docName: docName, operations: (batch) {}), throwsA(isA<StateError>()));
      });

      test('should handle encrypted documents during batch operations', () async {
        final jsonData = jsonEncode({key: value});
        final encryptedData = storage.encodeDocument(docName: docName, data: jsonData, encryptionPassword: encryptionPassword);

        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => encryptedData);

        await storage.batch(
          docName: docName,
          operations: (batch) {
            batch.write('newKey', 'newValue');
            batch.remove(key);
          },
          encryptionPassword: encryptionPassword,
        );

        final capturedWrite = verify(mockFile.writeAsString(captureAny)).captured.single;
        final decryptedData = storage.decodeDocument(docName, capturedWrite, encryptionPassword);
        final updatedDocument = jsonDecode(decryptedData) as Map<String, dynamic>;

        expect(updatedDocument.containsKey('newKey'), isTrue);
        expect(updatedDocument['newKey'], equals('newValue'));
        expect(updatedDocument.containsKey(key), isFalse);
      });
    });
  });
}
