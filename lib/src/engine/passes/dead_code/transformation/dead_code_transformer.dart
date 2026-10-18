import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/builder/kernel_builder.dart';
import 'package:refractor/src/engine/pass/transformation/pass_transformer.dart';
import 'package:refractor/src/engine/passes/dead_code/planning/dead_code_plan.dart';
import 'package:refractor/src/engine/passes/dead_code/planning/planned_dead_code.dart';
import 'package:refractor/src/engine/passes/dead_code/transformation/dead_code_transform_output.dart';

/// Inserts a guarded dead-code block into each planned function body.
///
/// The guard is always false — `(v & 0xFFFF) * (v & 0xFFFF) < 0`, a masked
/// square that never goes negative — so the block never runs and behaviour is
/// unchanged. It reads a live `int` in scope at the insertion point (a
/// parameter at the start of the body, or a local just after its declaration),
/// so it is not a compile-time constant and cannot be folded away.
final class DeadCodeTransformer
    implements PassTransformer<DeadCodePlan, DeadCodeTransformOutput> {
  const DeadCodeTransformer();

  @override
  Future<DeadCodeTransformOutput> apply(
    Component component,
    DeadCodePlan plan,
  ) async {
    if (plan.decisionCount == 0) {
      return const DeadCodeTransformOutput(insertedCount: 0);
    }

    final builder = KernelBuilder(component);
    for (final decision in plan.decisions) {
      _insert(decision, builder);
    }
    return DeadCodeTransformOutput(insertedCount: plan.decisionCount);
  }

  void _insert(PlannedDeadCode decision, KernelBuilder builder) {
    final variable = decision.site.variable;
    final block = decision.function.body! as Block;
    Expression ref() => VariableGet(variable);

    final guard = builder.lt(
      builder.mul(
        builder.bitAnd(ref(), builder.intLit(0xFFFF)),
        builder.bitAnd(ref(), builder.intLit(0xFFFF)),
      ),
      builder.intLit(0),
    );
    final deadBlock = Block([
      ExpressionStatement(
        builder.add(ref(), builder.intLit(decision.constantA)),
      ),
      ExpressionStatement(
        builder.mul(ref(), builder.intLit(decision.constantB)),
      ),
    ]);

    final guardedIf = IfStatement(guard, deadBlock, null);
    block.statements.insert(decision.site.insertionIndex, guardedIf);
    guardedIf.parent = block;
  }
}
