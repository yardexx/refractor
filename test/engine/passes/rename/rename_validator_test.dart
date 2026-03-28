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
