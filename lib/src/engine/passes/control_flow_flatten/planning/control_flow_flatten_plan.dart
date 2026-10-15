import 'package:refractor/src/engine/pass/planning/pass_plan.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/planning/planned_control_flow_flatten.dart';

/// The per-function flattening decisions, in selection order.
final class ControlFlowFlattenPlan extends PassPlan {
  ControlFlowFlattenPlan({
    required List<PlannedControlFlowFlatten> decisions,
  }) : decisions = List.unmodifiable(decisions);

  final List<PlannedControlFlowFlatten> decisions;

  int get decisionCount => decisions.length;
}
