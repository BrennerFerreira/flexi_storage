import 'package:flutter_test/flutter_test.dart';
import 'package:simple_storage/simple_storage.dart';

void main() {
  group('TimeBasedCacheStrategy', () {
    late TimeBasedCacheStrategy<String, String> cache;

    setUp(() {
      cache = TimeBasedCacheStrategy(ttl: Duration(seconds: 2)); // Initialize with a TTL of 2 seconds
    });

    test('should store and retrieve values within TTL', () async {
      cache.write('key1', 'value1');
      expect(cache.read('key1'), equals('value1'));
    });

    test('should return null for expired keys', () async {
      cache.write('key1', 'value1');
      await Future.delayed(Duration(seconds: 3)); // Wait for TTL to expire
      expect(cache.read('key1'), isNull);
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

    test('should not return expired keys when checking existence', () async {
      cache.write('key1', 'value1');
      await Future.delayed(Duration(seconds: 3)); // Wait for TTL to expire
      expect(cache.hasKey('key1'), isFalse);
    });
  });
}
