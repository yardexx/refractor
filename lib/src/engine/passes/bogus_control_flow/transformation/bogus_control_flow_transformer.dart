import 'package:kernel/ast.dart';
import 'package:kernel/clone.dart';
import 'package:refractor/src/engine/kernel_toolkit/builder/kernel_builder.dart';
import 'package:refractor/src/engine/pass/transformation/pass_transformer.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/planning/bogus_control_flow_plan.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/planning/planned_bogus_control_flow.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/transformation/bogus_control_flow_transform_output.dart';

/// Wraps each planned function body in an always-true opaque branch whose
/// else-branch is a faithful clone of the real body.
///
/// The result is `if (opaqueTrue) { realBody } else { clonedBody }`. The guard
/// — `(v & 0xFFFF) * (v & 0xFFFF) >= 0`, a masked square that is never negative
/// — always selects the real branch, so behaviour is unchanged; but it reads a
/// live parameter, so the compiler cannot fold it, and the clone is real-
/// looking code an attacker must rule out (unlike obvious dead-code junk).
final class BogusControlFlowTransformer
    implements
        PassTransformer<BogusControlFlowPlan, BogusControlFlowTransformOutput> {
  const BogusControlFlowTransformer();

  @override
  Future<BogusControlFlowTransformOutput> apply(
    Component component,
    BogusControlFlowPlan plan,
  ) async {
    if (plan.decisionCount == 0) {
      return const BogusControlFlowTransformOutput(insertedCount: 0);
    }

    final builder = KernelBuilder(component);
    for (final decision in plan.decisions) {
      _wrap(decision, builder);
    }
    return BogusControlFlowTransformOutput(insertedCount: plan.decisionCount);
  }

  void _wrap(PlannedBogusControlFlow decision, KernelBuilder builder) {
    final function = decision.function;
    final realBody = function.body! as Block;

    // Clone the real body into the never-executed branch. The cloner asserts a
    // clone exists for every variable read, so pre-register the parameters as
    // mapping to themselves — the clone never runs, so reading the real
    // parameters from it is harmless. Locals declared inside the body are
    // cloned (and remapped) as the body is walked.
    final cloner = CloneVisitorNotMembers();
    for (final parameter in function.positionalParameters) {
      cloner.setVariableClone(parameter, parameter);
    }
    for (final parameter in function.namedParameters) {
      cloner.setVariableClone(parameter, parameter);
    }
    final bogusBody = cloner.clone(realBody);

    Expression ref() => VariableGet(decision.guardVariable);
    final alwaysTrue = builder.ge(
      builder.mul(
        builder.bitAnd(ref(), builder.intLit(0xFFFF)),
        builder.bitAnd(ref(), builder.intLit(0xFFFF)),
      ),
      builder.intLit(0),
    );

    final guarded = IfStatement(alwaysTrue, realBody, bogusBody);
    function.body = Block([guarded])..parent = function;
  }
}
