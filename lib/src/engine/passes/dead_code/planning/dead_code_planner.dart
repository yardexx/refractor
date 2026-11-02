import 'dart:math';

import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/planning/pass_planner.dart';
import 'package:refractor/src/engine/passes/dead_code/planning/dead_code_plan.dart';
import 'package:refractor/src/engine/passes/dead_code/planning/planned_dead_code.dart';
import 'package:refractor/src/engine/passes/dead_code/selection/dead_code_selection.dart';

/// Assigns each target function a guard site, a guard shape and the junk its
/// dead block computes. Seeded, so a given seed yields the same plan every run.
///
/// The shape varies per block — one to four junk steps over random operators
/// and constants, sometimes mixing the guard variable back in, ending in one of
/// the sinks the function allows — so blocks do not share a fixed template.
final class DeadCodePlanner
    implements PassPlanner<DeadCodeSelection, DeadCodePlan> {
  DeadCodePlanner({required int seed}) : _random = Random(seed);

  static const int _maxConstant = 0xFFFF;
  static const int _maxSteps = 4;

  // The guard squares `v & mask`; masks stay at or below 24 bits so the square
  // fits in 48 bits — exact even where `int` is a double (web) — and is never
  // negative.
  static const int _minMask = 0xFF;
  static const int _maxMask = 0xFFFFFF;

  final Random _random;

  @override
  DeadCodePlan plan(
    Component component,
    DeadCodeSelection selection,
  ) {
    final decisions = <PlannedDeadCode>[];
    for (final function in selection.orderedFunctions) {
      final sites = selection.sitesFor(function);
      final site = sites[_random.nextInt(sites.length)];
      decisions.add(
        PlannedDeadCode(
          function: function,
          site: site,
          mask: _minMask + _random.nextInt(_maxMask - _minMask + 1),
          bound: _random.nextInt(_maxConstant + 1),
          steps: [
            for (var i = _random.nextInt(_maxSteps) + 1; i > 0; i--) _step(),
          ],
          sink: _sink(function, site),
        ),
      );
    }
    return DeadCodePlan(decisions: decisions);
  }

  DeadCodeStep _step() {
    final op = DeadCodeOp.values[_random.nextInt(DeadCodeOp.values.length)];
    if (op == DeadCodeOp.shl) {
      return DeadCodeStep(op: op, constant: _random.nextInt(31) + 1);
    }
    return DeadCodeStep(
      op: op,
      constant: _random.nextInt(_maxConstant) + 1,
      usesVariable: _random.nextInt(4) == 0,
    );
  }

  DeadCodeSink _sink(FunctionNode function, DeadCodeSite site) {
    final candidates = [
      DeadCodeSink.throwValue,
      if (canReassign(function, site)) DeadCodeSink.reassign,
      if (canReturnInt(function)) DeadCodeSink.returnValue,
    ];
    return candidates[_random.nextInt(candidates.length)];
  }
}
