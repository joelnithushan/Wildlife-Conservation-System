import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/errors/failures.dart';

void main() {
  group('Failure types', () {
    test('NetworkFailure has correct default message', () {
      const failure = NetworkFailure();
      expect(failure.message, 'No internet connection.');
    });

    test('CacheFailure has correct default message', () {
      const failure = CacheFailure();
      expect(failure.message, 'Local storage error.');
    });

    test('ServerFailure has correct default message', () {
      const failure = ServerFailure();
      expect(failure.message, 'Server error. Please try again.');
    });

    test('Two failures with same message are equal', () {
      const a = NetworkFailure('test');
      const b = NetworkFailure('test');
      expect(a, equals(b));
    });

    test('Two failures with different messages are not equal', () {
      const a = NetworkFailure('a');
      const b = NetworkFailure('b');
      expect(a, isNot(equals(b)));
    });
  });
}
