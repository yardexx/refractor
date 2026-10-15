import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/config/control_flow_flatten_config.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/planning/control_flow_flatten_plan.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/planning/control_flow_flatten_planner.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/selection/control_flow_flatten_selection.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/selection/control_flow_flatten_selector.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/transformation/control_flow_flatten_transform_output.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/transformation/control_flow_flatten_transformer.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Obfuscation pass that flattens straight-line function bodies into a
/// switch-dispatch state machine, hiding the linear order of statements.
///
/// This prototype only flattens synchronous bodies that are a block of two or
/// more expression statements — there are no local declarations to rescope and
/// no control flow or returns to reorder. Handling those is a follow-up.
///
/// Each stage delegates to its own class; the methods below are the seam.
class ControlFlowFlattenPass
    extends
        StagedPass<
          ControlFlowFlattenSelection,
          ControlFlowFlattenPlan,
          ControlFlowFlattenTransformOutput
        > {
  ControlFlowFlattenPass({
    required this.config,
    required this.scope,
  });

  final ControlFlowFlattenPassConfig config;
  final ObfuscationScope scope;

  @override
  String get name => 'control_flow_flatten';

  @override
  ControlFlowFlattenSelection select(Component component) =>
      ControlFlowFlattenSelector(scope: scope).select(component);

  @override
  Future<ControlFlowFlattenPlan> plan(
    Component component,
    ControlFlowFlattenSelection selection,
  ) => ControlFlowFlattenPlanner(
    seed: config.seed,
  ).plan(component, selection);

  @override
  Future<ControlFlowFlattenTransformOutput> transform(
    Component component,
    ControlFlowFlattenPlan plan,
  ) => const ControlFlowFlattenTransformer().apply(component, plan);

  @override
  PassReport buildReport(
    ControlFlowFlattenSelection selection,
    ControlFlowFlattenTransformOutput output,
  ) {
    return PassReport(
      passName: name,
      metadata: output.flattenedCount == 0
          ? const {}
          : {'functions_flattened': '${output.flattenedCount}'},
    );
  }
}
