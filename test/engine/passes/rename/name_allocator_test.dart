import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/name_generator.dart';
import 'package:refractor/src/engine/passes/rename/name_allocator.dart';
import 'package:refractor/src/engine/passes/rename/override_family/override_family_analysis.dart';
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

    test('each family gets a unique name', () {
      final classA = Class(name: 'A', fileUri: userLib.fileUri);
      final classB = Class(name: 'B', fileUri: userLib.fileUri);
      userLib
        ..addClass(classA)
        ..addClass(classB);

      final memberA = makeProcedure('foo', classA);
      final memberB = makeProcedure('bar', classB);

      final analysis = OverrideFamilyAnalysis(
        familyOf: {memberA: 0, memberB: 1},
      );

      final generator = NameGenerator(seed: 42);
      final result = allocator.allocate(analysis, generator);

      expect(result[memberA]!.text, isNot(equals(result[memberB]!.text)));
    });

    test('same family members get the same name', () {
      final parent = Class(name: 'Parent', fileUri: userLib.fileUri);
      final child = Class(name: 'Child', fileUri: userLib.fileUri);
      userLib
        ..addClass(parent)
        ..addClass(child);

      final memberP = makeProcedure('foo', parent);
      final memberC = makeProcedure('foo', child);

      final analysis = OverrideFamilyAnalysis(
        familyOf: {memberP: 0, memberC: 0},
      );

      final generator = NameGenerator(seed: 42);
      final result = allocator.allocate(analysis, generator);

      expect(result[memberP]!.text, equals(result[memberC]!.text));
    });

    test('private family gets underscore-prefixed name', () {
      final cls = Class(name: 'A', fileUri: userLib.fileUri);
      userLib.addClass(cls);

      final member = Procedure(
        Name('_secret', userLib),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: cls.fileUri,
      );
      cls.addProcedure(member);

      final analysis = OverrideFamilyAnalysis(
        familyOf: {member: 0},
      );

      final generator = NameGenerator(seed: 42);
      final result = allocator.allocate(analysis, generator);

      expect(result[member]!.text, startsWith('_'));
    });
  });
}
