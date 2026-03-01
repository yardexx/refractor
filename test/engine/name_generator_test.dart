import 'package:refractor/src/engine/name_generator.dart';
import 'package:test/test.dart';

void main() {
  group('NameGenerator', () {
    test('generates sequential names with default prefix', () {
      final generator = NameGenerator();

      expect(generator.next(), r'_$0');
      expect(generator.next(), r'_$1');
      expect(generator.next(), r'_$2');
    });

    test('supports custom prefix', () {
      final generator = NameGenerator(prefix: 'obf_');

      expect(generator.next(), 'obf_0');
      expect(generator.next(), 'obf_1');
    });

    test('reset restarts sequence', () {
      final generator = NameGenerator()
        ..next()
        ..next()
        ..reset();

      expect(generator.currentCount, 0);
      expect(generator.next(), r'_$0');
    });
  });
}
