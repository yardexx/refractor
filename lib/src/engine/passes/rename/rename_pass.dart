import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/rename/config/rename_config.dart';
import 'package:refractor/src/engine/passes/rename/planning/name_generator/name_generator.dart';
import 'package:refractor/src/engine/passes/rename/planning/name_generator/shuffled_generator.dart';
import 'package:refractor/src/engine/passes/rename/planning/rename_planner.dart';
import 'package:refractor/src/engine/passes/rename/selection/rename_selection.dart';
import 'package:refractor/src/engine/passes/rename/selection/rename_selector.dart';
import 'package:refractor/src/engine/passes/rename/transformation/rename_transform_output.dart';
import 'package:refractor/src/engine/passes/rename/transformation/rename_transformer.dart';
import 'package:refractor/src/engine/passes/rename/validation/rename_validator.dart';
import 'package:refractor/src/policy/rename_policy_view.dart';
import 'package:refractor/src/project/project_scope.dart';

typedef NameGeneratorFactory = NameGenerator Function();

/// Obfuscation pass that renames user-defined identifiers.
///
/// Safety note: named parameters on non-static instance methods are preserved.
/// Kernel dynamic invocations do not have enough target information to rewrite
/// those labels soundly once the receiver type becomes `dynamic`.
///
/// Orchestrates the rename pass internal pipeline:
///   1. Select eligible declarations.
///   2. Plan exact rename decisions.
///   3. Apply the planned mutations.
///   4. Validate post-mutation invariants.
///   5. Report stable pass output.
class RenamePass extends Pass {
  RenamePass({
    required this.config,
    required this.policy,
    required this.projectScope,
    NameGeneratorFactory? generatorFactory,
  }) : _generatorFactory =
           generatorFactory ?? (() => ShuffledGenerator(seed: config.seed));

  final RenamePassConfig config;
  final RenamePolicyView policy;
  final ProjectScope projectScope;
  final NameGeneratorFactory _generatorFactory;

  @override
  String get name => 'rename';

  @override
  Future<PassResult> run(Component component) async {
    try {
      final selection = RenameSelector(
        policy: policy,
        projectScope: projectScope,
      ).select(component);
      final plan =
          RenamePlanner(
            generator: _generatorFactory(),
          ).plan(
            component,
            selection,
          );
      final resolvedPlan = await plan;
      final output = await RenameTransformer(
        projectScope: projectScope,
      ).apply(component, resolvedPlan);
      const RenameValidator().validate(
        component,
        plan: resolvedPlan,
        output: output,
      );
      final artifact = output.artifact;
      final report = PassReport(
        passName: name,
        message: _buildMessage(selection, output),
        metadata: {
          'classes': output.renamedClasses.toString(),
          'members': output.renamedMembers.toString(),
          'variables': output.renamedVariables.toString(),
        },
      );

      return PassSucceeded(
        artifact: artifact,
        report: report,
      );
    } on Object catch (error) {
      final exception = error is Exception
          ? error
          : Exception(error.toString());
      return PassFailed(
        error: exception,
        report: PassReport(
          passName: name,
          message: error.toString(),
        ),
      );
    }
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
