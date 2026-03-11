import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/model/generated_names.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_scope.dart';
import 'package:refractor/src/engine/passes/rename/name_allocator.dart';
import 'package:refractor/src/engine/passes/rename/override_family/override_families.dart';
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

      final familyA = OverrideFamily(
        members: {memberA},
        root: memberA,
        isPrivate: false,
      );
      final familyB = OverrideFamily(
        members: {memberB},
        root: memberB,
        isPrivate: false,
      );

      final scope = RenameScope(
        overrideFamilies: OverrideFamilies(
          families: [familyA, familyB],
          familyOf: {memberA: familyA, memberB: familyB},
        ),
        classScopes: [],
        topLevelMembers: [],
        variables: [],
      );

      final names = GeneratedNames(
        familyNames: {familyA: 'x', familyB: 'y'},
        singletonNames: {},
        classNames: {},
        variableNames: {},
      );

      final result = allocator.allocate(scope, names);

      expect(result.members[memberA]!.text, 'x');
      expect(result.members[memberB]!.text, 'y');
      expect(
        result.members[memberA]!.text,
        isNot(equals(result.members[memberB]!.text)),
      );
    });

    test('same family members get the same name', () {
      final parent = Class(name: 'Parent', fileUri: userLib.fileUri);
      final child = Class(name: 'Child', fileUri: userLib.fileUri);
      userLib
        ..addClass(parent)
        ..addClass(child);

      final memberP = makeProcedure('foo', parent);
      final memberC = makeProcedure('foo', child);

      final family = OverrideFamily(
        members: {memberP, memberC},
        root: memberP,
        isPrivate: false,
      );

      final scope = RenameScope(
        overrideFamilies: OverrideFamilies(
          families: [family],
          familyOf: {memberP: family, memberC: family},
        ),
        classScopes: [],
        topLevelMembers: [],
        variables: [],
      );

      final names = GeneratedNames(
        familyNames: {family: 'abc'},
        singletonNames: {},
        classNames: {},
        variableNames: {},
      );

      final result = allocator.allocate(scope, names);

      expect(
        result.members[memberP]!.text,
        equals(result.members[memberC]!.text),
      );
      expect(result.members[memberP]!.text, 'abc');
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

      final family = OverrideFamily(
        members: {member},
        root: member,
        isPrivate: true,
        libraryScope: userLib,
      );

      final scope = RenameScope(
        overrideFamilies: OverrideFamilies(
          families: [family],
          familyOf: {member: family},
        ),
        classScopes: [],
        topLevelMembers: [],
        variables: [],
      );

      final names = GeneratedNames(
        familyNames: {family: 'abc'},
        singletonNames: {},
        classNames: {},
        variableNames: {},
      );

      final result = allocator.allocate(scope, names);

      expect(result.members[member]!.text, startsWith('_'));
      expect(result.members[member]!.text, '_abc');
    });

    test('allocates class names', () {
      final cls = Class(name: 'MyClass', fileUri: userLib.fileUri);
      userLib.addClass(cls);

      final scope = RenameScope(
        overrideFamilies: OverrideFamilies(families: [], familyOf: {}),
        classScopes: [ClassScope(node: cls)],
        topLevelMembers: [],
        variables: [],
      );

      final names = GeneratedNames(
        familyNames: {},
        singletonNames: {},
        classNames: {cls: 'X'},
        variableNames: {},
      );

      final result = allocator.allocate(scope, names);

      expect(result.classes[cls], 'X');
    });

    test('allocates variable names', () {
      final v = VariableDeclaration('myVar');

      final scope = RenameScope(
        overrideFamilies: OverrideFamilies(families: [], familyOf: {}),
        classScopes: [],
        topLevelMembers: [],
        variables: [v],
      );

      final names = GeneratedNames(
        familyNames: {},
        singletonNames: {},
        classNames: {},
        variableNames: {v: 'z'},
      );

      final result = allocator.allocate(scope, names);

      expect(result.variables[v], 'z');
    });

    test('builds symbolMap from all categories', () {
      final cls = Class(name: 'MyClass', fileUri: userLib.fileUri);
      userLib.addClass(cls);
      final member = makeProcedure('foo', cls);
      final v = VariableDeclaration('myVar');

      final family = OverrideFamily(
        members: {member},
        root: member,
        isPrivate: false,
      );

      final scope = RenameScope(
        overrideFamilies: OverrideFamilies(
          families: [family],
          familyOf: {member: family},
        ),
        classScopes: [ClassScope(node: cls)],
        topLevelMembers: [],
        variables: [v],
      );

      final names = GeneratedNames(
        familyNames: {family: 'a'},
        singletonNames: {},
        classNames: {cls: 'B'},
        variableNames: {v: 'c'},
      );

      final result = allocator.allocate(scope, names);

      expect(result.symbolMap['foo'], 'a');
      expect(result.symbolMap['MyClass'], 'B');
      expect(result.symbolMap['myVar'], 'c');
    });

    test('allocates singleton members', () {
      final topLevel = Procedure(
        Name('topFn'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(topLevel);

      final scope = RenameScope(
        overrideFamilies: OverrideFamilies(families: [], familyOf: {}),
        classScopes: [],
        topLevelMembers: [topLevel],
        variables: [],
      );

      final names = GeneratedNames(
        familyNames: {},
        singletonNames: {topLevel: 'q'},
        classNames: {},
        variableNames: {},
      );

      final result = allocator.allocate(scope, names);

      expect(result.members[topLevel]!.text, 'q');
      expect(result.symbolMap['topFn'], 'q');
    });
  });
}
