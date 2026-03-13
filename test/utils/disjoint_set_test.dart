import 'package:refractor/src/utils/disjoint_set.dart';
import 'package:test/test.dart';

void main() {
  group('DisjointSet', () {
    late DisjointSet<String> ds;

    setUp(() {
      ds = DisjointSet<String>();
    });

    test('find on fresh element returns itself', () {
      expect(ds.find('a'), equals('a'));
    });

    test('union merges two sets so find returns same root', () {
      ds.union('a', 'b');
      expect(ds.find('a'), equals(ds.find('b')));
    });

    test('union is idempotent', () {
      ds.union('a', 'b');
      final rootBefore = ds.find('a');
      ds.union('a', 'b');
      expect(ds.find('a'), equals(rootBefore));
      expect(ds.find('a'), equals(ds.find('b')));
    });

    test('union same element is no-op', () {
      ds.union('a', 'a');
      expect(ds.find('a'), equals('a'));
    });

    test(
      'transitivity: union(a,b) + union(b,c) implies find(a) == find(c)',
      () {
        ds
          ..union('a', 'b')
          ..union('b', 'c');
        expect(ds.find('a'), equals(ds.find('c')));
      },
    );

    test('disjoint sets stay separate', () {
      ds
        ..union('a', 'b')
        ..union('x', 'y');
      expect(ds.find('a'), isNot(equals(ds.find('x'))));
    });

    test('works with int type', () {
      final intDs = DisjointSet<int>()
        ..union(1, 2)
        ..union(2, 3);
      expect(intDs.find(1), equals(intDs.find(3)));
      expect(intDs.find(4), equals(4));
    });

    test('works with String type', () {
      ds.union('hello', 'world');
      expect(ds.find('hello'), equals(ds.find('world')));
    });

    test('large union: 100 elements share one root', () {
      final largeDs = DisjointSet<int>();
      for (var i = 1; i < 100; i++) {
        largeDs.union(0, i);
      }
      final root = largeDs.find(0);
      for (var i = 0; i < 100; i++) {
        expect(largeDs.find(i), equals(root));
      }
    });
  });
}
