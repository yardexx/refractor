import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/name_generator.dart';
import 'package:refractor/src/engine/passes/rename/name_allocator.dart';
import 'package:refractor/src/engine/passes/rename/override_family_analyzer.dart';
import 'package:test/test.dart';

import '../../../helpers/kernel_helpers.dart';

void main() {
  group('NameAllocator', () {
    late Library userLib;
    late NameAllocator allocator;

    setUp(() {
      userLib = makeUserLibrary();
      allocator = NameAllocator();
    });

    test('two unrelated families can share a name', () {
      final classA = Class(name: 'A', fileUri: userLib.fileUri);
      final classB = Class(name: 'B', fileUri: userLib.fileUri);
      userLib
        ..addClass(classA)
        ..addClass(classB);

      final analysis = OverrideFamilyAnalysis(
        familyOf: {},
        familyClasses: {
          0: {classA},
          1: {classB},
        },
        subtypesOf: {
          classA: {classA},
          classB: {classB},
        },
      );

      final generator = NameGenerator(seed: 42);
      final result = allocator.allocate(
        analysis,
        generator,
        libraryForFamily: (_) => userLib,
        isPrivateFamily: (_) => false,
      );

      // Both families should get the same name since they're
      // unrelated (no subtype overlap).
      expect(result[0]!.text, equals(result[1]!.text));
    });

    test('two related families cannot share a name', () {
      final parent = Class(name: 'Parent', fileUri: userLib.fileUri);
      final child = Class(
        name: 'Child',
        fileUri: userLib.fileUri,
      );
      userLib
        ..addClass(parent)
        ..addClass(child);

      final analysis = OverrideFamilyAnalysis(
        familyOf: {},
        familyClasses: {
          0: {parent},
          1: {child},
        },
        subtypesOf: {
          parent: {parent, child},
          child: {child},
        },
      );

      final generator = NameGenerator(seed: 42);
      final result = allocator.allocate(
        analysis,
        generator,
        libraryForFamily: (_) => userLib,
        isPrivateFamily: (_) => false,
      );

      expect(result[0]!.text, isNot(equals(result[1]!.text)));
    });

    test('three-family scenario with partial overlap', () {
      final classA = Class(name: 'A', fileUri: userLib.fileUri);
      final classB = Class(name: 'B', fileUri: userLib.fileUri);
      final classC = Class(name: 'C', fileUri: userLib.fileUri);
      userLib
        ..addClass(classA)
        ..addClass(classB)
        ..addClass(classC);

      // F0 = {A}, F1 = {B (subtype of A)}, F2 = {C (unrelated)}
      final analysis = OverrideFamilyAnalysis(
        familyOf: {},
        familyClasses: {
          0: {classA},
          1: {classB},
          2: {classC},
        },
        subtypesOf: {
          classA: {classA, classB},
          classB: {classB},
          classC: {classC},
        },
      );

      final generator = NameGenerator(seed: 42);
      final result = allocator.allocate(
        analysis,
        generator,
        libraryForFamily: (_) => userLib,
        isPrivateFamily: (_) => false,
      );

      // F0 and F1 overlap → different names.
      expect(result[0]!.text, isNot(equals(result[1]!.text)));
      // F2 is unrelated to both → can share with F0 or F1.
      expect(
        result[2]!.text == result[0]!.text ||
            result[2]!.text == result[1]!.text,
        isTrue,
      );
    });
  });
}
