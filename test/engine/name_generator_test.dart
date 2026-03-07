import 'package:refractor/src/engine/name_generator.dart';
import 'package:test/test.dart';

void main() {
  group('NameGenerator', () {
    test('generates alphabetic names', () {
      final generator = NameGenerator(seed: 42);

      final first = generator.next();
      final second = generator.next();
      final third = generator.next();

      expect(first, matches(RegExp(r'^[a-zA-Z]+$')));
      expect(second, matches(RegExp(r'^[a-zA-Z]+$')));
      expect(third, matches(RegExp(r'^[a-zA-Z]+$')));
      // All unique.
      expect({first, second, third}.length, 3);
    });

    test('same seed produces same sequence', () {
      final gen1 = NameGenerator(seed: 123);
      final gen2 = NameGenerator(seed: 123);

      for (var i = 0; i < 10; i++) {
        expect(gen1.next(), equals(gen2.next()));
      }
    });

    test('different seeds produce different sequences', () {
      final gen1 = NameGenerator(seed: 1);
      final gen2 = NameGenerator(seed: 2);

      // At least one of the first few names should differ.
      final names1 = List.generate(5, (_) => gen1.next());
      final names2 = List.generate(5, (_) => gen2.next());
      expect(names1, isNot(equals(names2)));
    });

    test('generates more than 52 unique names', () {
      final generator = NameGenerator(seed: 42);
      final names = <String>{};
      for (var i = 0; i < 100; i++) {
        names.add(generator.next());
      }
      expect(names.length, 100);
    });

    test('currentCount tracks number of names generated', () {
      final generator = NameGenerator(seed: 42);
      expect(generator.currentCount, 0);
      generator.next();
      expect(generator.currentCount, 1);
      generator.next();
      expect(generator.currentCount, 2);
    });

    test('default seed derives from project name', () {
      final gen1 = NameGenerator(projectName: 'myapp');
      final gen2 = NameGenerator(projectName: 'myapp');
      final gen3 = NameGenerator(projectName: 'other');

      final name1 = gen1.next();
      final name2 = gen2.next();
      final name3 = gen3.next();

      expect(name1, equals(name2));
      expect(name1, isNot(equals(name3)));
    });
  });
}
