import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/config/bogus_control_flow_config.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/planning/bogus_control_flow_plan.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/planning/bogus_control_flow_planner.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/selection/bogus_control_flow_selection.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/selection/bogus_control_flow_selector.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/transformation/bogus_control_flow_transform_output.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/transformation/bogus_control_flow_transformer.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Obfuscation pass that wraps a function body in an always-true opaque branch
/// whose else-branch is a faithful clone of the real body.
///
/// The body becomes `if (opaqueTrue) { realBody } else { clonedBody }`. The
/// guard always selects the real branch, so behaviour is preserved, but it
/// reads a live `int` parameter (so the optimizer cannot fold it) and the
/// clone is plausible, real-looking code — unlike the obvious junk of the
/// dead-code pass, an attacker cannot dismiss it at a glance.
///
/// Only synchronous functions with a non-nullable int parameter and a body of
/// at most `maxStatements` statements are wrapped; keying on in-scope locals
/// and partial-body branches are follow-ups.
class BogusControlFlowPass
    extends
        StagedPass<
          BogusControlFlowSelection,
          BogusControlFlowPlan,
          BogusControlFlowTransformOutput
        > {
  BogusControlFlowPass({
    required this.config,
    required this.scope,
  });

  final BogusControlFlowPassConfig config;
  final ObfuscationScope scope;

  @override
  String get name => 'bogus_control_flow';

  @override
  BogusControlFlowSelection select(Component component) =>
      BogusControlFlowSelector(
        scope: scope,
        maxStatements: config.maxStatements,
      ).select(component);

  @override
  Future<BogusControlFlowPlan> plan(
    Component component,
    BogusControlFlowSelection selection,
  ) => BogusControlFlowPlanner(seed: config.seed).plan(component, selection);

  @override
  Future<BogusControlFlowTransformOutput> transform(
    Component component,
    BogusControlFlowPlan plan,
  ) => const BogusControlFlowTransformer().apply(component, plan);

  @override
  PassReport buildReport(
    BogusControlFlowSelection selection,
    BogusControlFlowTransformOutput output,
  ) {
    return PassReport(
      passName: name,
      metadata: output.insertedCount == 0
          ? const {}
          : {'bogus_branches_inserted': '${output.insertedCount}'},
    );
  }
}
