import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/dead_code/config/dead_code_config.dart';
import 'package:refractor/src/engine/passes/dead_code/planning/dead_code_plan.dart';
import 'package:refractor/src/engine/passes/dead_code/planning/dead_code_planner.dart';
import 'package:refractor/src/engine/passes/dead_code/selection/dead_code_selection.dart';
import 'package:refractor/src/engine/passes/dead_code/selection/dead_code_selector.dart';
import 'package:refractor/src/engine/passes/dead_code/transformation/dead_code_transform_output.dart';
import 'package:refractor/src/engine/passes/dead_code/transformation/dead_code_transformer.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Obfuscation pass that prepends a never-executed, opaquely-guarded block to
/// function bodies, adding plausible code a reader must rule out.
///
/// The guard is an always-false predicate over a live `int` parameter, so the
/// block never runs (behaviour is preserved) but is not a compile-time constant
/// the optimizer can drop. This prototype guards on a parameter; using in-scope
/// locals or richer junk is a follow-up.
///
/// Each stage delegates to its own class; the methods below are the seam.
class DeadCodePass
    extends
        StagedPass<DeadCodeSelection, DeadCodePlan, DeadCodeTransformOutput> {
  DeadCodePass({
    required this.config,
    required this.scope,
  });

  final DeadCodePassConfig config;
  final ObfuscationScope scope;

  @override
  String get name => 'dead_code';

  @override
  DeadCodeSelection select(Component component) =>
      DeadCodeSelector(scope: scope).select(component);

  @override
  Future<DeadCodePlan> plan(
    Component component,
    DeadCodeSelection selection,
  ) => DeadCodePlanner(seed: config.seed).plan(component, selection);

  @override
  Future<DeadCodeTransformOutput> transform(
    Component component,
    DeadCodePlan plan,
  ) => const DeadCodeTransformer().apply(component, plan);

  @override
  PassReport buildReport(
    DeadCodeSelection selection,
    DeadCodeTransformOutput output,
  ) {
    return PassReport(
      passName: name,
      metadata: output.insertedCount == 0
          ? const {}
          : {'blocks_inserted': '${output.insertedCount}'},
    );
  }
}
