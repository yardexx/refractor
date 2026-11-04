import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/rename/config/rename_config.dart';
import 'package:refractor/src/engine/passes/rename/planning/name_generator/name_generator.dart';
import 'package:refractor/src/engine/passes/rename/planning/name_generator/shuffled_generator.dart';
import 'package:refractor/src/engine/passes/rename/planning/rename_plan.dart';
import 'package:refractor/src/engine/passes/rename/planning/rename_planner.dart';
import 'package:refractor/src/engine/passes/rename/reporting/rename_artifact.dart';
import 'package:refractor/src/engine/passes/rename/selection/rename_selection.dart';
import 'package:refractor/src/engine/passes/rename/selection/rename_selector.dart';
import 'package:refractor/src/engine/passes/rename/transformation/rename_transform_output.dart';
import 'package:refractor/src/engine/passes/rename/transformation/rename_transformer.dart';
import 'package:refractor/src/engine/passes/rename/validation/rename_validator.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

typedef NameGeneratorFactory = NameGenerator Function();

/// Obfuscation pass that renames user-defined identifiers.
///
/// Safety note: named parameters on non-static instance methods are preserved.
/// Kernel dynamic invocations do not have enough target information to rewrite
/// those labels soundly once the receiver type becomes `dynamic`.
///
/// Each stage delegates to its own class under this pass's directory; the
/// methods below are the pipeline seam.
class RenamePass
    extends StagedPass<RenameSelection, RenamePlan, RenameTransformOutput> {
  RenamePass({
    required this.config,
    required this.scope,
    NameGeneratorFactory? generatorFactory,
  }) : _generatorFactory =
           generatorFactory ?? (() => ShuffledGenerator(seed: config.seed));

  final RenamePassConfig config;
  final ObfuscationScope scope;
  final NameGeneratorFactory _generatorFactory;

  @override
  String get name => 'rename';

  @override
  RenameSelection select(Component component) =>
      RenameSelector(scope: scope).select(component);

  @override
  RenamePlan plan(Component component, RenameSelection selection) =>
      RenamePlanner(generator: _generatorFactory()).plan(component, selection);

  @override
  RenameTransformOutput transform(
    Component component,
    RenamePlan plan,
  ) => RenameTransformer(scope: scope).apply(component, plan);

  @override
  void validate(
    Component component, {
    required RenamePlan plan,
    required RenameTransformOutput output,
  }) => const RenameValidator().validate(
    component,
    plan: plan,
    output: output,
  );

  @override
  RenameArtifact buildArtifact(RenameTransformOutput output) => output.artifact;

  @override
  PassReport buildReport(
    RenameSelection selection,
    RenameTransformOutput output,
  ) {
    return PassReport(
      passName: name,
      message: _buildMessage(selection, output),
      metadata: {
        'classes': output.renamedClasses.toString(),
        'members': output.renamedMembers.toString(),
        'variables': output.renamedVariables.toString(),
      },
    );
  }

  String _buildMessage(
    RenameSelection selection,
    RenameTransformOutput output,
  ) {
    final eligibleMembers =
        selection.singletonMembers.length +
        selection.instanceMembersByClass.values.fold<int>(
          0,
          (sum, members) => sum + members.length,
        );
    final renamedAnything =
        output.renamedClasses > 0 ||
        output.renamedMembers > 0 ||
        output.renamedVariables > 0;
    final selectedAnything =
        selection.classes.isNotEmpty ||
        eligibleMembers > 0 ||
        selection.variables.isNotEmpty;

    if (!renamedAnything && !selectedAnything) {
      return 'No eligible declarations selected for rename.';
    }

    return 'Renamed ${output.renamedClasses} classes, '
        '${output.renamedMembers} members, and '
        '${output.renamedVariables} variables.';
  }
}
