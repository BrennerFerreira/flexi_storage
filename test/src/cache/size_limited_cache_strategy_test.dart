import 'package:flutter_test/flutter_test.dart';
import 'package:simple_storage/simple_storage.dart';

void main() {
  group('SizeLimitedCacheStrategy', () {
    late SizeLimitedCacheStrategy<String, String> cache;

    setUp(() {
      cache = SizeLimitedCacheStrategy(maxSize: 3); // Initialize with a max size of 3
    });

    test('should store and retrieve values', () {
      cache.write('key1', 'value1');
      expect(cache.read('key1'), equals('value1'));
    });

    test('should return null for non-existent keys', () {
      expect(cache.read('nonExistentKey'), isNull);
    });

    test('should evict the oldest item when capacity is exceeded', () {
      cache.write('key1', 'value1');
      cache.write('key2', 'value2');
      cache.write('key3', 'value3');
      cache.write('key4', 'value4'); // Exceeds capacity

      expect(cache.read('key1'), isNull); // key1 should be evicted
      expect(cache.read('key2'), equals('value2'));
      expect(cache.read('key3'), equals('value3'));
      expect(cache.read('key4'), equals('value4'));
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
