import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/materialization/name_materializer.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_plan.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_slot.dart';
import 'package:test/test.dart';

import '../../../../helpers/kernel_helpers.dart';

void main() {
  group('NameMaterializer', () {
    late Library userLib;

    setUp(() {
      userLib = makeUserLibrary();
    });

    test('expands a member family to shared member names', () {
      final cls = Class(name: 'Svc', fileUri: userLib.fileUri);
      final first = makeProcedure('run', cls);
      final second = makeProcedure('run', cls);
      userLib.addClass(cls);

      final family = MemberFamily(
        members: {first, second},
        originalName: 'run',
      );
      final slot = RenameSlot.family(family);
      final mapping = NameMaterializer().materialize({slot: 'a'});

      expect(mapping.members[first]!.text, 'a');
      expect(mapping.members[second]!.text, 'a');
      expect(mapping.symbolMap['a'], 'run');
    });

    test('materializes private singleton names with library scope', () {
      final member = Procedure(
        Name('_secret', userLib),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(member);

      final slot = RenameSlot.singletonMember(member, '_secret');
      final mapping = NameMaterializer().materialize({slot: 'b'});

      expect(mapping.members[member]!.text, '_b');
      expect(mapping.members[member]!.library, same(userLib));
      expect(mapping.symbolMap['${userLib.importUri}::_b'], '_secret');
      expect(mapping.symbolMap['_b'], '_secret');
    });

    test('keeps private symbol-map entries distinct across libraries', () {
      final otherLib = makeUserLibrary('src/other.dart');
      final first = Procedure(
        Name('_secret', userLib),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      final second = Procedure(
        Name('_secret', otherLib),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: otherLib.fileUri,
      );
      userLib.addProcedure(first);
      otherLib.addProcedure(second);

      final firstSlot = RenameSlot.singletonMember(first, '_secret');
      final secondSlot = RenameSlot.singletonMember(second, '_secret');
      final mapping = NameMaterializer().materialize({
        firstSlot: 'a',
        secondSlot: 'a',
      });

      expect(mapping.symbolMap['${userLib.importUri}::_a'], '_secret');
      expect(mapping.symbolMap['${otherLib.importUri}::_a'], '_secret');
      expect(mapping.symbolMap['_a'], '_secret');
      expect(mapping.symbolMap, hasLength(3));
    });

    test('omits bare private symbol-map key when scoped originals differ', () {
      final otherLib = makeUserLibrary('src/other.dart');
      final first = Procedure(
        Name('_secret', userLib),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      final second = Procedure(
        Name('_hidden', otherLib),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: otherLib.fileUri,
      );
      userLib.addProcedure(first);
      otherLib.addProcedure(second);

      final firstSlot = RenameSlot.singletonMember(first, '_secret');
      final secondSlot = RenameSlot.singletonMember(second, '_hidden');
      final mapping = NameMaterializer().materialize({
        firstSlot: 'a',
        secondSlot: 'a',
      });

      expect(mapping.symbolMap['${userLib.importUri}::_a'], '_secret');
      expect(mapping.symbolMap['${otherLib.importUri}::_a'], '_hidden');
      expect(mapping.symbolMap.containsKey('_a'), isFalse);
    });

    test('materializes class and variable names into symbol map', () {
      final cls = Class(name: 'Tracker', fileUri: userLib.fileUri);
      final variable = VariableDeclaration('count');

      final classSlot = RenameSlot.classType(cls);
      final variableSlot = RenameSlot.variable(variable, 'count');
      final mapping = NameMaterializer().materialize({
        classSlot: 'C',
        variableSlot: 'v',
      });

      expect(mapping.classes[cls], 'C');
      expect(mapping.variables[variable], 'v');
      expect(mapping.symbolMap['C'], 'Tracker');
      expect(mapping.symbolMap['v'], 'count');
    });
  });
}
