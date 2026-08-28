import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/pass/validation/pass_validator.dart';
import 'package:refractor/src/engine/passes/rename/planning/rename_plan.dart';
import 'package:refractor/src/engine/passes/rename/transformation/rename_transform_output.dart';
import 'package:refractor/src/utils/rename_helpers.dart';

final class RenameValidator
    implements PassValidator<RenamePlan, RenameTransformOutput> {
  const RenameValidator();

  @override
  void validate(
    Component component, {
    required RenamePlan plan,
    required RenameTransformOutput output,
  }) {
    final mapping = plan.mapping;
    if (output.renamedClasses != plan.plannedClasses) {
      throw StateError(
        'Rename transform count mismatch for classes: '
        '${output.renamedClasses} != ${plan.plannedClasses}',
      );
    }
    if (output.renamedMembers != plan.plannedMembers) {
      throw StateError(
        'Rename transform count mismatch for members: '
        '${output.renamedMembers} != ${plan.plannedMembers}',
      );
    }
    if (output.renamedVariables != plan.plannedVariables) {
      throw StateError(
        'Rename transform count mismatch for variables: '
        '${output.renamedVariables} != ${plan.plannedVariables}',
      );
    }

    for (final entry in mapping.classes.entries) {
      if (entry.key.name != entry.value) {
        throw StateError(
          'Class ${entry.key} was not renamed to the planned name '
          '${entry.value}.',
        );
      }
    }

    for (final entry in mapping.members.entries) {
      if (!sameName(entry.key.name, entry.value)) {
        throw StateError(
          'Member ${entry.key} was not renamed to the planned name '
          '${entry.value}.',
        );
      }
    }

    for (final entry in mapping.variables.entries) {
      if (entry.key.name != entry.value) {
        throw StateError(
          'Variable ${entry.key} was not renamed to the planned name '
          '${entry.value}.',
        );
      }
    }
  }
}
