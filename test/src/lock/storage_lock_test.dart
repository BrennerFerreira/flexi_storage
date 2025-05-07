import 'package:flutter_test/flutter_test.dart';
import 'package:simple_storage/src/lock/storage_lock.dart';

void main() {
  group('StorageLock', () {
    late StorageLock storageLock;

    setUp(() {
      storageLock = StorageLock();
    });

    test('executes actions sequentially', () async {
      final results = <int>[];

      await Future.wait([
        storageLock.synchronized(() async {
          await Future.delayed(Duration(milliseconds: 100));
          results.add(1);
        }),
        storageLock.synchronized(() async {
          results.add(2);
        }),
      ]);

      expect(results, [1, 2]);
    });

    test('handles exceptions without deadlocking', () async {
      final results = <int>[];

      try {
        await storageLock.synchronized(() async {
          results.add(1);
          throw Exception('Test exception');
        });
      } catch (e) {
        // Expected exception
      }

      await storageLock.synchronized(() async {
        results.add(2);
      });

      expect(results, [1, 2]);
    });
  });
}
