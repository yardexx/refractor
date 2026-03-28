import 'package:refractor/src/engine/passes/rename/planning/name_generator/sequential_generator.dart';
import 'package:refractor/src/engine/passes/rename/planning/name_generator/shuffled_generator.dart';
import 'package:test/test.dart';

void main() {
  group('ShuffledGenerator', () {
    test('generates alphabetic names', () {
      final generator = ShuffledGenerator(seed: 42);

      final first = generator.nextName();
      final second = generator.nextName();
      final third = generator.nextName();

      expect(first, matches(RegExp(r'^[a-zA-Z]+$')));
      expect(second, matches(RegExp(r'^[a-zA-Z]+$')));
      expect(third, matches(RegExp(r'^[a-zA-Z]+$')));
      // All unique.
      expect({first, second, third}.length, 3);
    });

    test('same seed produces same sequence', () {
      final gen1 = ShuffledGenerator(seed: 123);
      final gen2 = ShuffledGenerator(seed: 123);

      for (var i = 0; i < 10; i++) {
        expect(gen1.nextName(), equals(gen2.nextName()));
      }
    });

    test('different seeds produce different sequences', () {
      final gen1 = ShuffledGenerator(seed: 1);
      final gen2 = ShuffledGenerator(seed: 2);

      final names1 = List.generate(5, (_) => gen1.nextName());
      final names2 = List.generate(5, (_) => gen2.nextName());
      expect(names1, isNot(equals(names2)));
    });

    test('generates more than 52 unique names', () {
      final generator = ShuffledGenerator(seed: 42);
      final names = <String>{};
      for (var i = 0; i < 100; i++) {
        names.add(generator.nextName());
      }
      expect(names.length, 100);
    });

    test('default seed derives from project name', () {
      final gen1 = ShuffledGenerator(projectName: 'myapp');
      final gen2 = ShuffledGenerator(projectName: 'myapp');
      final gen3 = ShuffledGenerator(projectName: 'other');

      final name1 = gen1.nextName();
      final name2 = gen2.nextName();
      final name3 = gen3.nextName();

      expect(name1, equals(name2));
      expect(name1, isNot(equals(name3)));
    });
  });

  group('SequentialGenerator', () {
    test('generates sequential alphabetic names', () {
      final generator = SequentialGenerator();

      expect(generator.nextName(), 'a');
      expect(generator.nextName(), 'b');
      expect(generator.nextName(), 'c');
    });

    test('wraps to two-character names after alphabet', () {
      final generator = SequentialGenerator();
      for (var i = 0; i < 52; i++) {
        generator.nextName();
      }
      final twoChar = generator.nextName();
      expect(twoChar.length, 2);
      expect(twoChar, matches(RegExp(r'^[a-zA-Z]{2}$')));
    });

    test('generates unique names', () {
      final generator = SequentialGenerator();
      final names = <String>{};
      for (var i = 0; i < 200; i++) {
        names.add(generator.nextName());
      }
      expect(names.length, 200);
    });
  });
}
