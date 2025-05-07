import 'package:flutter_test/flutter_test.dart';
import 'package:flexi_storage/src/lock/storage_lock.dart';

void main() {
  group('StorageLock', () {
    late StorageLock storageLock;

    setUp(() {
      storageLock = StorageLock();
    });

    test('executes actions sequentially', () async {
      final List<int> results = <int>[];

      await Future.wait<void>(<Future<void>>[
        storageLock.synchronized(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          results.add(1);
        }),
        storageLock.synchronized(() async {
          results.add(2);
        }),
      ]);

      expect(results, <int>[1, 2]);
    });

    test('handles exceptions without deadlocking', () async {
      final List<int> results = <int>[];

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

      expect(results, <int>[1, 2]);
    });
  });
}
