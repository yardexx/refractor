import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/planning/rename_plan.dart';
import 'package:refractor/src/engine/passes/rename/reporting/rename_artifact.dart';
import 'package:refractor/src/engine/passes/rename/reporting/rename_mapping.dart';
import 'package:refractor/src/engine/passes/rename/transformation/rename_transform_output.dart';
import 'package:refractor/src/engine/passes/rename/validation/rename_validator.dart';
import 'package:test/test.dart';

void main() {
  group('RenameValidator', () {
    RenamePlan makePlan() {
      final library = Library(
        Uri.parse('package:app/app.dart'),
        fileUri: Uri.parse('package:app/app.dart'),
      );
      final cls = Class(name: 'Tracker', fileUri: library.fileUri);
      final member = Procedure(
        Name('work'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: library.fileUri,
      );
      final variable = VariableDeclaration('value');
      final mapping = RenameMapping(
        members: {member: Name('a')},
        classes: {cls: 'B'},
        variables: {variable: 'c'},
      );
      cls.name = 'B';
      member.name = Name('a');
      variable.name = 'c';
      return RenamePlan(
        mapping: mapping,
        plannedClasses: 1,
        plannedMembers: 1,
        plannedVariables: 1,
      );
    }

    test('accepts matching counts and artifact', () {
      final plan = makePlan();
      expect(
        () => const RenameValidator().validate(
          Component(),
          plan: plan,
          output: RenameTransformOutput(
            renamedClasses: 1,
            renamedMembers: 1,
            renamedVariables: 1,
            artifact: RenameArtifact(mapping: plan.mapping),
          ),
        ),
        returnsNormally,
      );
    });

    test('fails when output diverges from planned mapping', () {
      final plan = makePlan();
      expect(
        () => const RenameValidator().validate(
          Component(),
          plan: plan,
          output: RenameTransformOutput(
            renamedClasses: 0,
            renamedMembers: 1,
            renamedVariables: 1,
            artifact: RenameArtifact(mapping: plan.mapping),
          ),
        ),
        throwsStateError,
      );
    });

    test('fails when two members in one class collide', () {
      final library = Library(
        Uri.parse('package:app/app.dart'),
        fileUri: Uri.parse('package:app/app.dart'),
      );
      final cls = Class(name: 'C', fileUri: library.fileUri);
      library.addClass(cls);
      final first = Procedure(
        Name('a'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: library.fileUri,
      );
      final second = Procedure(
        Name('a'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: library.fileUri,
      );
      cls
        ..addProcedure(first)
        ..addProcedure(second);
      final mapping = RenameMapping(
        members: {first: Name('a'), second: Name('a')},
        classes: const {},
        variables: const {},
      );

      expect(
        () => const RenameValidator().validate(
          Component(),
          plan: RenamePlan(
            mapping: mapping,
            plannedClasses: 0,
            plannedMembers: 2,
            plannedVariables: 0,
          ),
          output: RenameTransformOutput(
            renamedClasses: 0,
            renamedMembers: 2,
            renamedVariables: 0,
            artifact: RenameArtifact(mapping: mapping),
          ),
        ),
        throwsStateError,
      );
    });

    test('allows a getter and setter renamed to the same name', () {
      final library = Library(
        Uri.parse('package:app/app.dart'),
        fileUri: Uri.parse('package:app/app.dart'),
      );
      final cls = Class(name: 'C', fileUri: library.fileUri);
      library.addClass(cls);
      final getter = Procedure(
        Name('a'),
        ProcedureKind.Getter,
        FunctionNode(EmptyStatement()),
        fileUri: library.fileUri,
      );
      final setter = Procedure(
        Name('a'),
        ProcedureKind.Setter,
        FunctionNode(
          EmptyStatement(),
          positionalParameters: [VariableDeclaration('v')],
        ),
        fileUri: library.fileUri,
      );
      cls
        ..addProcedure(getter)
        ..addProcedure(setter);
      final mapping = RenameMapping(
        members: {getter: Name('a'), setter: Name('a')},
        classes: const {},
        variables: const {},
      );

      expect(
        () => const RenameValidator().validate(
          Component(),
          plan: RenamePlan(
            mapping: mapping,
            plannedClasses: 0,
            plannedMembers: 2,
            plannedVariables: 0,
          ),
          output: RenameTransformOutput(
            renamedClasses: 0,
            renamedMembers: 2,
            renamedVariables: 0,
            artifact: RenameArtifact(mapping: mapping),
          ),
        ),
        returnsNormally,
      );
    });

    test('allows a field and getter renamed to the same name', () {
      final library = Library(
        Uri.parse('package:app/app.dart'),
        fileUri: Uri.parse('package:app/app.dart'),
      );
      final cls = Class(name: 'C', fileUri: library.fileUri);
      library.addClass(cls);
      final field = Field.mutable(Name('a'), fileUri: library.fileUri);
      final getter = Procedure(
        Name('a'),
        ProcedureKind.Getter,
        FunctionNode(EmptyStatement()),
        fileUri: library.fileUri,
      );
      cls
        ..addField(field)
        ..addProcedure(getter);
      final mapping = RenameMapping(
        members: {field: Name('a'), getter: Name('a')},
        classes: const {},
        variables: const {},
      );

      expect(
        () => const RenameValidator().validate(
          Component(),
          plan: RenamePlan(
            mapping: mapping,
            plannedClasses: 0,
            plannedMembers: 2,
            plannedVariables: 0,
          ),
          output: RenameTransformOutput(
            renamedClasses: 0,
            renamedMembers: 2,
            renamedVariables: 0,
            artifact: RenameArtifact(mapping: mapping),
          ),
        ),
        returnsNormally,
      );
    });

    test('fails when two classes in one library collide', () {
      final library = Library(
        Uri.parse('package:app/app.dart'),
        fileUri: Uri.parse('package:app/app.dart'),
      );
      final first = Class(name: 'Alpha', fileUri: library.fileUri);
      final second = Class(name: 'Beta', fileUri: library.fileUri);
      library
        ..addClass(first)
        ..addClass(second);
      first.name = 'X';
      second.name = 'X';
      final mapping = RenameMapping(
        members: const {},
        classes: {first: 'X', second: 'X'},
        variables: const {},
      );

      expect(
        () => const RenameValidator().validate(
          Component(),
          plan: RenamePlan(
            mapping: mapping,
            plannedClasses: 2,
            plannedMembers: 0,
            plannedVariables: 0,
          ),
          output: RenameTransformOutput(
            renamedClasses: 2,
            renamedMembers: 0,
            renamedVariables: 0,
            artifact: RenameArtifact(mapping: mapping),
          ),
        ),
        throwsStateError,
      );
    });

    test('fails when a mapped declaration was not actually renamed', () {
      final library = Library(
        Uri.parse('package:app/app.dart'),
        fileUri: Uri.parse('package:app/app.dart'),
      );
      final cls = Class(name: 'Tracker', fileUri: library.fileUri);
      final mapping = RenameMapping(
        members: const {},
        classes: {cls: 'B'},
        variables: const {},
      );

      expect(
        () => const RenameValidator().validate(
          Component(),
          plan: RenamePlan(
            mapping: mapping,
            plannedClasses: 1,
            plannedMembers: 0,
            plannedVariables: 0,
          ),
          output: RenameTransformOutput(
            renamedClasses: 1,
            renamedMembers: 0,
            renamedVariables: 0,
            artifact: RenameArtifact(mapping: mapping),
          ),
        ),
        throwsStateError,
      );
    });
  });
}
