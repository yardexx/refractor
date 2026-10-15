import 'dart:math';

import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/planning/pass_planner.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/planning/control_flow_flatten_plan.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/planning/planned_control_flow_flatten.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/selection/control_flow_flatten_selection.dart';

/// Shuffles the case layout of each selected function. Seeded, so a given seed
/// yields the same layouts every run.
final class ControlFlowFlattenPlanner
    implements
        PassPlanner<ControlFlowFlattenSelection, ControlFlowFlattenPlan> {
  ControlFlowFlattenPlanner({required int seed}) : _random = Random(seed);

  final Random _random;

  @override
  Future<ControlFlowFlattenPlan> plan(
    Component component,
    ControlFlowFlattenSelection selection,
  ) async {
    final decisions = <PlannedControlFlowFlatten>[];
    for (final function in selection.orderedFunctions) {
      final blockCount = (function.body! as Block).statements.length;
      final layout = [for (var i = 0; i < blockCount; i++) i]..shuffle(_random);
      decisions.add(
        PlannedControlFlowFlatten(function: function, layout: layout),
      );
    }
    return ControlFlowFlattenPlan(decisions: decisions);
  }
}
