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

/// Obfuscation pass that inserts a never-executed, opaquely-guarded block into
/// function bodies, adding plausible code a reader must rule out.
///
/// The guard is an always-false predicate over a live `int` in scope at the
/// insertion point — a parameter at the start of the body, or a block-local
/// just after it is declared. The block never runs (behaviour is preserved) but
/// is not a compile-time constant the optimizer can drop. The block's junk ends
/// in an effect (a write to a live variable, a `return` or a `throw`) so the
/// AOT compiler keeps it in the machine code.
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
  DeadCodePlan plan(
    Component component,
    DeadCodeSelection selection,
  ) => DeadCodePlanner(seed: config.seed).plan(component, selection);

  @override
  DeadCodeTransformOutput transform(
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
