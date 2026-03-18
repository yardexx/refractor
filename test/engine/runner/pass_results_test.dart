import 'package:refractor/src/engine/runner/pass_results.dart';
import 'package:test/test.dart';

void main() {
  group('PassResults', () {
    late PassResults results;

    setUp(() {
      results = PassResults();
    });

    test('add + get round-trips value', () {
      results.add('rename', 'mapping-data');
      expect(results.get<String>('rename'), equals('mapping-data'));
    });

    test('get returns null for missing key', () {
      expect(results.get<String>('nonexistent'), isNull);
    });

    test('add with null value is ignored', () {
      results.add('rename', null);
      expect(results.get<Object>('rename'), isNull);
    });

    test('multiple passes store independently', () {
      results
        ..add('rename', 42)
        ..add('encrypt', 'secret');
      expect(results.get<int>('rename'), equals(42));
      expect(results.get<String>('encrypt'), equals('secret'));
    });

    test('later add overwrites earlier value', () {
      results
        ..add('rename', 'first')
        ..add('rename', 'second');
      expect(results.get<String>('rename'), equals('second'));
    });
  });
}
