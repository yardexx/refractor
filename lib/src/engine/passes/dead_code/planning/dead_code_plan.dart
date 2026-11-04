import 'package:refractor/src/engine/pass/planning/pass_plan.dart';
import 'package:refractor/src/engine/passes/dead_code/planning/planned_dead_code.dart';

/// The per-function dead-code insertions, in selection order.
final class DeadCodePlan extends PassPlan {
  DeadCodePlan({
    required List<PlannedDeadCode> decisions,
  }) : decisions = List.unmodifiable(decisions);

  final List<PlannedDeadCode> decisions;

  int get decisionCount => decisions.length;
}
