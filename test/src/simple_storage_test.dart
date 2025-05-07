import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'dart:io';
import 'package:simple_storage/src/simple_storage.dart';
import 'package:simple_storage/src/utils/file_handler.dart';
import 'package:simple_storage/src/utils/is_web_util.dart';

import 'simple_storage_test.mocks.dart';

@GenerateMocks([Directory])
void main() {
  group('SimpleStorage init method', () {
    late SimpleStorage storage;
    late MockDirectory mockDirectory;

    const path = 'test_path';

    setUp(() async {
      storage = SimpleStorage();
      mockDirectory = MockDirectory();
      when(mockDirectory.path).thenReturn(path);
    });

    tearDown(() async {
      IsWebUtil.override = false; // Reset web override
      FileHandler.mockDirectory = null; // Reset mock directory
    });

    test('should initialize on web platform', () async {
      IsWebUtil.override = true; // Simulate web
      expect(storage.isInitialized, isFalse);

      await storage.init('');

      expect(storage.isInitialized, isTrue);
    });

    test('should initialize and create directory on non-web platform', () async {
      FileHandler.mockDirectory = mockDirectory;
      when(mockDirectory.exists()).thenAnswer((_) async => false);
      when(mockDirectory.create(recursive: true)).thenAnswer((_) async => mockDirectory);

      expect(storage.isInitialized, isFalse);

      await storage.init(path);

      expect(storage.isInitialized, isTrue);
      verify(mockDirectory.create(recursive: true)).called(1);
    });

    test('should not reinitialize if already initialized', () async {
      FileHandler.mockDirectory = mockDirectory;
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
}
