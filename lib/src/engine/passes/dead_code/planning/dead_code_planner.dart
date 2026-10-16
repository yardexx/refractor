import 'dart:math';

import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/planning/pass_planner.dart';
import 'package:refractor/src/engine/passes/dead_code/planning/dead_code_plan.dart';
import 'package:refractor/src/engine/passes/dead_code/planning/planned_dead_code.dart';
import 'package:refractor/src/engine/passes/dead_code/selection/dead_code_selection.dart';

/// Assigns each target function a guard site and the constants used in its dead
/// block. Seeded, so a given seed yields the same plan every run.
final class DeadCodePlanner
    implements PassPlanner<DeadCodeSelection, DeadCodePlan> {
  DeadCodePlanner({required int seed}) : _random = Random(seed);

  static const int _maxConstant = 0xFFFF;

  final Random _random;

  @override
  Future<DeadCodePlan> plan(
    Component component,
    DeadCodeSelection selection,
  ) async {
    final decisions = <PlannedDeadCode>[];
    for (final function in selection.orderedFunctions) {
      final sites = selection.sitesFor(function);
      final site = sites[_random.nextInt(sites.length)];
      decisions.add(
        PlannedDeadCode(
          function: function,
          site: site,
          constantA: _random.nextInt(_maxConstant) + 1,
          constantB: _random.nextInt(_maxConstant) + 1,
        ),
      );
    }
    return DeadCodePlan(decisions: decisions);
  }
}
