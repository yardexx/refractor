import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/planning/pass_plan.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/planning/planned_arithmetic_mangle.dart';

/// The per-site mangle decisions, keyed by invocation for lookup during the
/// bottom-up transform.
final class ArithmeticManglePlan extends PassPlan {
  ArithmeticManglePlan({
    required Map<InstanceInvocation, PlannedArithmeticMangle> decisions,
  }) : _decisions = Map.unmodifiable(decisions);

  final Map<InstanceInvocation, PlannedArithmeticMangle> _decisions;

  int get decisionCount => _decisions.length;

  PlannedArithmeticMangle? decisionFor(InstanceInvocation node) =>
      _decisions[node];
}
