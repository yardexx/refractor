import 'package:refractor/src/engine/pass/planning/pass_plan.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/planning/planned_opaque_predicate.dart';

/// The per-site strengthening decisions, in selection order.
final class OpaquePredicatePlan extends PassPlan {
  OpaquePredicatePlan({
    required List<PlannedOpaquePredicate> decisions,
  }) : decisions = List.unmodifiable(decisions);

  final List<PlannedOpaquePredicate> decisions;

  int get decisionCount => decisions.length;
}
