import 'dart:convert';

import 'package:flexi_storage/src/operations/batch_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'dart:io';
import 'package:flexi_storage/src/flexi_storage.dart';
import 'package:flexi_storage/src/utils/file_handler.dart';
import 'package:flexi_storage/src/utils/is_web_util.dart';

import 'flexi_storage_test.mocks.dart';

@GenerateNiceMocks(<MockSpec<dynamic>>[MockSpec<Directory>(), MockSpec<File>()])
void main() {
  late FlexiStorage storage;
  late MockDirectory mockDirectory;
  late MockFile mockFile;

  const String path = 'test_path';
  const String docName = 'testDoc';
  const String key = 'testKey';
  const String value = 'testValue';
  const String encryptionPassword = 'securePassword';

  setUp(() async {
    storage = FlexiStorage();
    mockDirectory = MockDirectory();
    mockFile = MockFile();

    when(mockDirectory.path).thenReturn(path);
    when(mockDirectory.exists()).thenAnswer((_) async => true);
    when(mockDirectory.create(recursive: true)).thenAnswer((_) async => mockDirectory);

    when(mockFile.exists()).thenAnswer((_) async => true);
    when(mockFile.create(recursive: true)).thenAnswer((_) async => mockFile);
    when(mockFile.writeAsString(captureAny)).thenAnswer((Invocation inv) async => mockFile);
    when(mockFile.delete()).thenAnswer((_) async => mockFile);

    FileHandler.mockDirectory = mockDirectory; // Set the mock directory
    FileHandler.mockFile = mockFile;
  });

  tearDown(() async {
    IsWebUtil.override = false; // Reset web override
    FileHandler.mockDirectory = null; // Reset mock directory
    FileHandler.mockFile = null; // Reset mock file
  });

  group("FlexiStorage", () {
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
        when(mockDirectory.create(recursive: true)).thenThrow(const FileSystemException('Failed to create directory'));

        expect(() async => await storage.init(path), throwsA(isA<FileSystemException>()));
      });
    });

    group('write', () {
      test('should write a key-value pair to a document', () async {
        await storage.init(path);

        when(mockFile.readAsString()).thenAnswer((_) async => '{}');
        await storage.write(docName: docName, key: key, value: value);

        verify(mockFile.writeAsString(jsonEncode(<String, String>{key: value}))).called(1);
      });

      test('should overwrite an existing key with a new value', () async {
        const String initialValue = 'initialValue';
        const String newValue = 'newValue';

        when(mockFile.readAsString()).thenAnswer((_) async => '{}');

        await storage.init(path);
        await storage.write(docName: docName, key: key, value: initialValue);
        await storage.write(docName: docName, key: key, value: newValue);

        verify(mockFile.writeAsString(jsonEncode(<String, String>{key: initialValue}))).called(1);
        verify(mockFile.writeAsString(jsonEncode(<String, String>{key: newValue}))).called(1);
      });

      test('should throw an exception if storage is not initialized', () async {
        when(mockFile.readAsString()).thenAnswer((_) async => '{}');
        expect(() async => await storage.write(docName: docName, key: key, value: value), throwsA(isA<StateError>()));
      });

      test('should write an encrypted document if encryptionPassword is provided', () async {
        when(mockFile.readAsString()).thenAnswer((_) async => '{}');
        const String encryptionPassword = 'securePassword';

        await storage.init(path);
        await storage.write(docName: docName, key: key, value: value, encryptionPassword: encryptionPassword);

        final VerificationResult capturedCall = verify(mockFile.writeAsString(captureAny));
        expect(capturedCall.captured.length, 1);
        final String encryptedData = capturedCall.captured[0] as String;
        expect(encryptedData, isA<String>());
        expect(encryptedData.startsWith('ENCRYPTED:'), isTrue);
      });
    });

    group('read', () {
      test('should read a value by key from a document', () async {
        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => jsonEncode(<String, String>{key: value}));

        final String? result = await storage.read<String>(docName: docName, key: key);

        expect(result, equals(value));
      });

      test('should return null if key does not exist in the document', () async {
        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => jsonEncode(<String, String>{}));

        final String? result = await storage.read<String>(docName: docName, key: key);

        expect(result, isNull);
      });

      test('should throw an exception if storage is not initialized', () async {
        expect(() async => await storage.read<String>(docName: docName, key: key), throwsA(isA<StateError>()));
      });

      test('should read an encrypted value if encryptionPassword is provided', () async {
        final String jsonData = jsonEncode(<String, String>{key: value});
        final String encryptedData = storage.encodeDocument(docName: docName, data: jsonData, encryptionPassword: encryptionPassword);

        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => encryptedData);

        final String? result = await storage.read<String>(docName: docName, key: key, encryptionPassword: encryptionPassword);

        expect(result, equals(value));
      });

      test('should return null if type mismatch occurs', () async {
        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => jsonEncode(<String, String>{key: value}));

        final int? result = await storage.read<int>(docName: docName, key: key);

        expect(result, isNull);
      });
    });

    group('remove', () {
      test('should remove a key-value pair from a document', () async {
        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => jsonEncode(<String, String>{key: value}));

        await storage.remove(docName: docName, key: key);

        verify(mockFile.writeAsString(jsonEncode(<String, String>{}))).called(1);
      });

      test('should throw an exception if storage is not initialized', () async {
        expect(() async => await storage.remove(docName: docName, key: key), throwsA(isA<StateError>()));
      });

      test('should remove an encrypted key-value pair if encryptionPassword is provided', () async {
        final String jsonData = jsonEncode(<String, String>{key: value});
        final String encryptedData = storage.encodeDocument(docName: docName, data: jsonData, encryptionPassword: encryptionPassword);

        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => encryptedData);

        await storage.remove(docName: docName, key: key, encryptionPassword: encryptionPassword);
        final VerificationResult capturedWrite = verify(mockFile.writeAsString(captureAny));
        final String decryptedData = storage.decodeDocument(docName, capturedWrite.captured[0], encryptionPassword);
        expect(decryptedData, equals(jsonEncode(<String, String>{})));
      });
    });

    group('clearDocument', () {
      test('should clear the contents of a document', () async {
        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => jsonEncode(<String, String>{key: value}));

        await storage.clearDocument(docName);

        verify(mockFile.writeAsString(jsonEncode(<String, String>{}))).called(1);
      });

      test('should throw an exception if storage is not initialized', () async {
        expect(() async => await storage.clearDocument(docName), throwsA(isA<StateError>()));
      });

      test('should clear an encrypted document if encryptionPassword is provided', () async {
        final String jsonData = jsonEncode(<String, String>{key: value});
        final String encryptedData = storage.encodeDocument(docName: docName, data: jsonData, encryptionPassword: encryptionPassword);

        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => encryptedData);

        await storage.clearDocument(docName);
        final VerificationResult capturedWrite = verify(mockFile.writeAsString(captureAny));
        final String decryptedData = storage.decodeDocument(docName, capturedWrite.captured[0], encryptionPassword);
        expect(decryptedData, equals(jsonEncode(<String, String>{})));
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
        final String jsonData = jsonEncode(<String, String>{key: value});
        final String encryptedData = storage.encodeDocument(docName: docName, data: jsonData, encryptionPassword: encryptionPassword);

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
        final Map<String, String> documentData = <String, String>{key: value, 'anotherKey': 'anotherValue'};
        when(mockFile.readAsString()).thenAnswer((_) async => jsonEncode(documentData));

        final List<String> keys = await storage.getKeys(docName);

        expect(keys, containsAll(documentData.keys));
      });

      test('should return an empty list if the document is empty', () async {
        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => jsonEncode(<String, String>{}));

        final List<String> keys = await storage.getKeys(docName);

        expect(keys, isEmpty);
      });

      test('should throw an exception if storage is not initialized', () async {
        expect(() async => await storage.getKeys(docName), throwsA(isA<StateError>()));
      });

      test('should return keys from an encrypted document if encryptionPassword is provided', () async {
        final Map<String, String> documentData = <String, String>{key: value, 'anotherKey': 'anotherValue'};
        final String jsonData = jsonEncode(documentData);
        final String encryptedData = storage.encodeDocument(docName: docName, data: jsonData, encryptionPassword: encryptionPassword);

        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => encryptedData);

        final List<String> keys = await storage.getKeys(docName, encryptionPassword: encryptionPassword);

        expect(keys, containsAll(documentData.keys));
      });
    });

    group('batch', () {
      test('should perform batch operations on a document', () async {
        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => jsonEncode(<String, String>{key: value}));

        await storage.batch(
          docName: docName,
          operations: (BatchOperation batch) {
            batch.write('newKey', 'newValue');
            batch.remove(key);
          },
        );

        final String capturedWrite = verify(mockFile.writeAsString(captureAny)).captured.single;
        final Map<String, dynamic> updatedDocument = jsonDecode(capturedWrite) as Map<String, dynamic>;

        expect(updatedDocument.containsKey('newKey'), isTrue);
        expect(updatedDocument['newKey'], equals('newValue'));
        expect(updatedDocument.containsKey(key), isFalse);
      });

      test('should throw an exception if storage is not initialized', () async {
        expect(() async => await storage.batch(docName: docName, operations: (BatchOperation batch) {}), throwsA(isA<StateError>()));
      });

      test('should handle encrypted documents during batch operations', () async {
        final String jsonData = jsonEncode(<String, String>{key: value});
        final String encryptedData = storage.encodeDocument(docName: docName, data: jsonData, encryptionPassword: encryptionPassword);

        await storage.init(path);
        when(mockFile.readAsString()).thenAnswer((_) async => encryptedData);

        await storage.batch(
          docName: docName,
          operations: (BatchOperation batch) {
            batch.write('newKey', 'newValue');
            batch.remove(key);
          },
          encryptionPassword: encryptionPassword,
        );

        final String capturedWrite = verify(mockFile.writeAsString(captureAny)).captured.single;
        final String decryptedData = storage.decodeDocument(docName, capturedWrite, encryptionPassword);
        final Map<String, dynamic> updatedDocument = jsonDecode(decryptedData) as Map<String, dynamic>;

        expect(updatedDocument.containsKey('newKey'), isTrue);
        expect(updatedDocument['newKey'], equals('newValue'));
        expect(updatedDocument.containsKey(key), isFalse);
      });
    });
  });
}
