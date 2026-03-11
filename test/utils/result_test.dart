import 'package:refractor/src/utils/result.dart';
import 'package:test/test.dart';

void main() {
  group('Result', () {
    test('Result.ok creates Ok with correct value', () {
      const result = Result<int>.ok(42);
      expect(result, isA<Ok<int>>());
      expect((result as Ok<int>).value, equals(42));
    });

    test('Result.error creates Error with correct exception', () {
      final exception = Exception('fail');
      final result = Result<int>.error(exception);
      expect(result, isA<Error<int>>());
      expect((result as Error<int>).error, same(exception));
    });

    test('pattern matching via switch works', () {
      const ok = Result<String>.ok('hello');
      final err = Result<String>.error(Exception('oops'));

      final okMessage = switch (ok) {
        Ok(:final value) => 'ok: $value',
        Error(:final error) => 'error: $error',
      };
      expect(okMessage, equals('ok: hello'));

      final errMessage = switch (err) {
        Ok(:final value) => 'ok: $value',
        Error(:final error) => 'error: $error',
      };
      expect(errMessage, startsWith('error: '));
    });

    test('Ok.toString() format', () {
      const result = Result<int>.ok(42);
      expect(result.toString(), equals('Result<int>.ok(42)'));
    });

    test('Error.toString() format', () {
      final result = Result<int>.error(Exception('boom'));
      expect(result.toString(), equals('Result<int>.error(Exception: boom)'));
    });
  });

  group('runCatching', () {
    test('wraps success as Ok', () {
      final result = runCatching(() => 42);
      expect(result, isA<Ok<int>>());
      expect((result as Ok<int>).value, equals(42));
    });

    test('wraps Exception as Error', () {
      final result = runCatching<int>(() => throw Exception('fail'));
      expect(result, isA<Error<int>>());
      expect(
        (result as Error<int>).error.toString(),
        contains('fail'),
      );
    });

    test('does not catch non-Exception errors (propagates)', () {
      expect(
        () => runCatching<int>(() => throw StateError('not an Exception')),
        throwsStateError,
      );
    });
  });
}
