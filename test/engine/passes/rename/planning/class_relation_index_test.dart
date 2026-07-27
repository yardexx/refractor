import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/rename/planning/class_relation_index.dart';
import 'package:test/test.dart';

/// Adds all [classes] to a fresh library so that `asThisSupertype` works.
Library _makeLib(List<Class> classes) {
  final uri = Uri.parse('test:test');
  final lib = Library(uri, fileUri: uri);
  classes.forEach(lib.addClass);
  return lib;
}

void main() {
  final fileUri = Uri.parse('test:test');

  group('ClassRelationIndex', () {
    test('lone class has empty subtypes', () {
      final a = Class(name: 'A', fileUri: fileUri);
      _makeLib([a]);
      final index = ClassRelationIndex.build([a]);

      expect(index.subtypesOf(a), isNot(contains(isNot(a))));
    });

    test('simple inheritance: supertypesOf child contains parent', () {
      final parent = Class(name: 'Parent', fileUri: fileUri);
      _makeLib([parent]);
      final child = Class(
        name: 'Child',
        fileUri: fileUri,
        supertype: parent.asThisSupertype,
      );
      parent.enclosingLibrary.addClass(child);
      final index = ClassRelationIndex.build([parent, child]);

      expect(index.supertypesOf(child), contains(parent));
    });

    test('simple inheritance: subtypesOf parent contains child', () {
      final parent = Class(name: 'Parent', fileUri: fileUri);
      _makeLib([parent]);
      final child = Class(
        name: 'Child',
        fileUri: fileUri,
        supertype: parent.asThisSupertype,
      );
      parent.enclosingLibrary.addClass(child);
      final index = ClassRelationIndex.build([parent, child]);

      expect(index.subtypesOf(parent), contains(child));
    });

    test('transitive supertypes: A extends B extends C', () {
      final c = Class(name: 'C', fileUri: fileUri);
      _makeLib([c]);
      final b = Class(
        name: 'B',
        fileUri: fileUri,
        supertype: c.asThisSupertype,
      );
      c.enclosingLibrary.addClass(b);
      final a = Class(
        name: 'A',
        fileUri: fileUri,
        supertype: b.asThisSupertype,
      );
      c.enclosingLibrary.addClass(a);
      final index = ClassRelationIndex.build([a, b, c]);

      final supertypesOfA = index.supertypesOf(a);
      expect(supertypesOfA, contains(b));
      expect(supertypesOfA, contains(c));
    });

    test('transitive subtypes: C -> B -> A', () {
      final c = Class(name: 'C', fileUri: fileUri);
      _makeLib([c]);
      final b = Class(
        name: 'B',
        fileUri: fileUri,
        supertype: c.asThisSupertype,
      );
      c.enclosingLibrary.addClass(b);
      final a = Class(
        name: 'A',
        fileUri: fileUri,
        supertype: b.asThisSupertype,
      );
      c.enclosingLibrary.addClass(a);
      final index = ClassRelationIndex.build([a, b, c]);

      final subtypesOfC = index.subtypesOf(c);
      expect(subtypesOfC, contains(b));
      expect(subtypesOfC, contains(a));
    });

    test('interface implementation: supertypesOf includes interface', () {
      final iface = Class(name: 'I', fileUri: fileUri);
      _makeLib([iface]);
      final a = Class(
        name: 'A',
        fileUri: fileUri,
        implementedTypes: [iface.asThisSupertype],
      );
      iface.enclosingLibrary.addClass(a);
      final index = ClassRelationIndex.build([a, iface]);

      expect(index.supertypesOf(a), contains(iface));
    });

    test('mixin: supertypesOf includes mixin', () {
      final m = Class(name: 'M', fileUri: fileUri);
      _makeLib([m]);
      final a = Class(
        name: 'A',
        fileUri: fileUri,
        mixedInType: m.asThisSupertype,
      );
      m.enclosingLibrary.addClass(a);
      final index = ClassRelationIndex.build([a, m]);

      expect(index.supertypesOf(a), contains(m));
    });

    test('areRelated returns true for parent-child', () {
      final parent = Class(name: 'Parent', fileUri: fileUri);
      _makeLib([parent]);
      final child = Class(
        name: 'Child',
        fileUri: fileUri,
        supertype: parent.asThisSupertype,
      );
      parent.enclosingLibrary.addClass(child);
      final index = ClassRelationIndex.build([parent, child]);

      expect(index.areRelated(parent, child), isTrue);
      expect(index.areRelated(child, parent), isTrue);
    });

    test('areRelated returns false for unrelated classes', () {
      final a = Class(name: 'A', fileUri: fileUri);
      final b = Class(name: 'B', fileUri: fileUri);
      _makeLib([a, b]);
      final index = ClassRelationIndex.build([a, b]);

      expect(index.areRelated(a, b), isFalse);
    });

    test(
      'shareScopedSubtype returns true for interfaces with common subtype',
      () {
        final ifaceA = Class(name: 'IA', fileUri: fileUri);
        final ifaceB = Class(name: 'IB', fileUri: fileUri);
        final lib = _makeLib([ifaceA, ifaceB]);
        final concrete = Class(
          name: 'Concrete',
          fileUri: fileUri,
          implementedTypes: [ifaceA.asThisSupertype, ifaceB.asThisSupertype],
        );
        lib.addClass(concrete);

        final index = ClassRelationIndex.build([ifaceA, ifaceB, concrete]);

        expect(index.shareScopedSubtype(ifaceA, ifaceB), isTrue);
      },
    );

    test(
      'shareScopedSubtype returns false without common in-scope subtype',
      () {
        final ifaceA = Class(name: 'IA', fileUri: fileUri);
        final ifaceB = Class(name: 'IB', fileUri: fileUri);
        _makeLib([ifaceA, ifaceB]);

        final index = ClassRelationIndex.build([ifaceA, ifaceB]);

        expect(index.shareScopedSubtype(ifaceA, ifaceB), isFalse);
      },
    );

    test(
      'shareDeclaringSupertypeForName returns true when common supertype '
      'declares member',
      () {
        final base = Class(name: 'Base', fileUri: fileUri)
          ..addProcedure(
            Procedure(
              Name('foo'),
              ProcedureKind.Method,
              FunctionNode(EmptyStatement()),
              fileUri: fileUri,
            ),
          );
        _makeLib([base]);
        final a = Class(
          name: 'A',
          fileUri: fileUri,
          supertype: base.asThisSupertype,
        );
        final b = Class(
          name: 'B',
          fileUri: fileUri,
          supertype: base.asThisSupertype,
        );
        base.enclosingLibrary
          ..addClass(a)
          ..addClass(b);
        final index = ClassRelationIndex.build([base, a, b]);

        expect(index.shareDeclaringSupertypeForName(a, b, 'foo'), isTrue);
      },
    );

    test(
      'shareDeclaringSupertypeForName returns false for undeclared name',
      () {
        final base = Class(name: 'Base', fileUri: fileUri)
          ..addProcedure(
            Procedure(
              Name('foo'),
              ProcedureKind.Method,
              FunctionNode(EmptyStatement()),
              fileUri: fileUri,
            ),
          );
        _makeLib([base]);
        final a = Class(
          name: 'A',
          fileUri: fileUri,
          supertype: base.asThisSupertype,
        );
        final b = Class(
          name: 'B',
          fileUri: fileUri,
          supertype: base.asThisSupertype,
        );
        base.enclosingLibrary
          ..addClass(a)
          ..addClass(b);
        final index = ClassRelationIndex.build([base, a, b]);

        expect(index.shareDeclaringSupertypeForName(a, b, 'bar'), isFalse);
      },
    );

    test(
      'shareDeclaringSupertypeForName returns false for unrelated classes',
      () {
        final a = Class(name: 'A', fileUri: fileUri);
        final b = Class(name: 'B', fileUri: fileUri);
        _makeLib([a, b]);
        final index = ClassRelationIndex.build([a, b]);

        expect(index.shareDeclaringSupertypeForName(a, b, 'foo'), isFalse);
      },
    );

    test('diamond hierarchy: D extends B, C; B extends A; C extends A', () {
      final a = Class(name: 'A', fileUri: fileUri);
      final lib = _makeLib([a]);
      final b = Class(
        name: 'B',
        fileUri: fileUri,
        supertype: a.asThisSupertype,
      );
      lib.addClass(b);
      final c = Class(
        name: 'C',
        fileUri: fileUri,
        supertype: a.asThisSupertype,
      );
      lib.addClass(c);
      final d = Class(
        name: 'D',
        fileUri: fileUri,
        supertype: b.asThisSupertype,
        implementedTypes: [c.asThisSupertype],
      );
      lib.addClass(d);
      final index = ClassRelationIndex.build([a, b, c, d]);

      final supertypesOfD = index.supertypesOf(d);
      expect(supertypesOfD, contains(a));
      expect(supertypesOfD, contains(b));
      expect(supertypesOfD, contains(c));
    });
  });
}
