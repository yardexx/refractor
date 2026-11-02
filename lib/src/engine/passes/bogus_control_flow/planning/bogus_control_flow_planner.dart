import 'dart:math';

import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/planning/pass_planner.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/planning/bogus_control_flow_plan.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/planning/planned_bogus_control_flow.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/selection/bogus_control_flow_selection.dart';

/// Picks the guard parameter for each target function. Seeded, so a given seed
/// yields the same plan every run.
final class BogusControlFlowPlanner
    implements PassPlanner<BogusControlFlowSelection, BogusControlFlowPlan> {
  BogusControlFlowPlanner({required int seed}) : _random = Random(seed);

  final Random _random;

  @override
  BogusControlFlowPlan plan(
    Component component,
    BogusControlFlowSelection selection,
  ) {
    final decisions = <PlannedBogusControlFlow>[];
    for (final function in selection.orderedFunctions) {
      final candidates = selection.guardCandidatesFor(function);
      final guard = candidates[_random.nextInt(candidates.length)];
      decisions.add(
        PlannedBogusControlFlow(function: function, guardVariable: guard),
      );
    }
    return BogusControlFlowPlan(decisions: decisions);
  }
}
