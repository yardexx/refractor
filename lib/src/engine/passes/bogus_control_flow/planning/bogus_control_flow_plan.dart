import 'package:refractor/src/engine/pass/planning/pass_plan.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/planning/planned_bogus_control_flow.dart';

/// The per-function bogus-branch decisions, in selection order.
final class BogusControlFlowPlan extends PassPlan {
  BogusControlFlowPlan({
    required List<PlannedBogusControlFlow> decisions,
  }) : decisions = List.unmodifiable(decisions);

  final List<PlannedBogusControlFlow> decisions;

  int get decisionCount => decisions.length;
}
