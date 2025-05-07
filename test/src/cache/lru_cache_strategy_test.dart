import 'package:flutter_test/flutter_test.dart';
import 'package:flexi_storage/flexi_storage.dart';

void main() {
  group('LRUCacheStrategy', () {
    late LRUCacheStrategy<String, String> cache;

    setUp(() {
      cache = LRUCacheStrategy(3); // Initialize with a capacity of 3
    });

    test('should store and retrieve values', () {
      cache.write('key1', 'value1');
      expect(cache.read('key1'), equals('value1'));
    });

    test('should return null for non-existent keys', () {
      expect(cache.read('nonExistentKey'), isNull);
    });

    test('should evict the least recently used item when capacity is exceeded', () {
      cache.write('key1', 'value1');
      cache.write('key2', 'value2');
      cache.write('key3', 'value3');
      cache.write('key4', 'value4'); // Exceeds capacity

      expect(cache.read('key1'), isNull); // key1 should be evicted
      expect(cache.read('key2'), equals('value2'));
      expect(cache.read('key3'), equals('value3'));
      expect(cache.read('key4'), equals('value4'));
    });

    test('should update access order on read', () {
      cache.write('key1', 'value1');
      cache.write('key2', 'value2');
      cache.write('key3', 'value3');

      // Access key1 to make it recently used
      cache.read('key1');

      // Add another key to exceed capacity
      cache.write('key4', 'value4');

      expect(cache.read('key2'), isNull); // key2 should be evicted
      expect(cache.read('key1'), equals('value1'));
    });

    test('should remove a key from the cache', () {
      cache.write('key1', 'value1');
      cache.remove('key1');

      expect(cache.read('key1'), isNull);
    });

    test('should check if a key exists in the cache', () {
      cache.write('key1', 'value1');

      expect(cache.hasKey('key1'), isTrue);
      expect(cache.hasKey('key2'), isFalse);
    });
  });
}
