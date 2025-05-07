import 'dart:developer';
import 'dart:io';
import 'package:flexi_storage/flexi_storage.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  // Use path_provider to get the application documents directory
  final Directory directory = await getApplicationDocumentsDirectory();
  final String storagePath = directory.path;

  // Initialize FlexiStorage
  final FlexiStorage storage = FlexiStorage();
  await storage.init(storagePath);
  log('Storage initialized at: $storagePath');

  // Store a key-value pair
  await storage.write(docName: 'exampleDoc', key: 'username', value: 'kiwify');
  log('Stored username: kiwify');

  // Retrieve the stored value
  final String? username = await storage.read<String>(docName: 'exampleDoc', key: 'username');
  log('Retrieved username: $username');

  // Update the value
  await storage.write(docName: 'exampleDoc', key: 'username', value: 'kiwify_updated');
  log('Updated username: kiwify_updated');

  // Retrieve the updated value
  final String? updatedUsername = await storage.read<String>(docName: 'exampleDoc', key: 'username');
  log('Retrieved updated username: $updatedUsername');

  // Remove the value
  await storage.remove(docName: 'exampleDoc', key: 'username');
  log('Removed username');

  // Demonstrate encryption
  const String password = 'securePassword';
  await storage.write(docName: 'secureDoc', key: 'secret', value: 'encryptedValue', encryptionPassword: password);
  log('Stored encrypted value.');

  final String? encryptedValue = await storage.read<String>(docName: 'secureDoc', key: 'secret', encryptionPassword: password);
  log('Retrieved encrypted value: $encryptedValue');

  // Demonstrate batch operations
  await storage.batch(
    docName: 'batchDoc',
    operations: (BatchOperation batch) {
      batch.write('key1', 'value1');
      batch.write('key2', 'value2');
      batch.write('key3', 'value3');
    },
  );
  log('Executed batch operations.');

  final String? batchValue1 = await storage.read<String>(docName: 'batchDoc', key: 'key1');
  final String? batchValue2 = await storage.read<String>(docName: 'batchDoc', key: 'key2');
  final String? batchValue3 = await storage.read<String>(docName: 'batchDoc', key: 'key3');

  log('Batch values: $batchValue1, $batchValue2, $batchValue3');
}
