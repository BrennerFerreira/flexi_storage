import 'package:flutter_test/flutter_test.dart';
import 'package:flexi_storage/src/operations/document_batch_operation.dart';

void main() {
  group('DocumentBatchOperation', () {
    late Map<String, dynamic> document;
    late DocumentBatchOperation batchOperation;

    setUp(() {
      document = <String, dynamic>{'key1': 'value1', 'key2': 42};
      batchOperation = DocumentBatchOperation(document);
    });

    test('write should add a new key-value pair and mark as modified', () {
      batchOperation.write('key3', true);
      expect(document['key3'], true);
      expect(batchOperation.modified, true);
    });

    test('read should return the correct value for an existing key', () {
      final String? value = batchOperation.read<String>('key1');
      expect(value, 'value1');
    });

    test('read should return null for a non-existing key', () {
      final String? value = batchOperation.read<String>('non_existing_key');
      expect(value, isNull);
    });

    test('hasKey should return true for an existing key', () {
      expect(batchOperation.hasKey('key1'), true);
    });

    test('hasKey should return false for a non-existing key', () {
      expect(batchOperation.hasKey('non_existing_key'), false);
    });

    test('remove should delete an existing key and mark as modified', () {
      batchOperation.remove('key1');
      expect(document.containsKey('key1'), false);
      expect(batchOperation.modified, true);
    });

    test('clear should empty the document and mark as modified', () {
      batchOperation.clear();
      expect(document.isEmpty, true);
      expect(batchOperation.modified, true);
    });
  });
}
