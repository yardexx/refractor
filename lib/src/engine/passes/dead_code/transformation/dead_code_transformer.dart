import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/builder/kernel_builder.dart';
import 'package:refractor/src/engine/pass/transformation/pass_transformer.dart';
import 'package:refractor/src/engine/passes/dead_code/planning/dead_code_plan.dart';
import 'package:refractor/src/engine/passes/dead_code/planning/planned_dead_code.dart';
import 'package:refractor/src/engine/passes/dead_code/selection/dead_code_selection.dart';
import 'package:refractor/src/engine/passes/dead_code/transformation/dead_code_transform_output.dart';

/// Prepends a guarded dead-code block to each planned function body.
///
/// The guard is always false — `(p & 0xFFFF) * (p & 0xFFFF) < 0`, a masked
/// square that never goes negative — so the block never runs and behaviour is
/// unchanged. It reads a live parameter, so it is not a compile-time constant
/// and cannot be folded away.
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
    final parameter = firstIntParam(decision.function)!;
    final block = decision.function.body! as Block;
    Expression ref() => VariableGet(parameter);

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
    block.statements.insert(0, guardedIf);
    guardedIf.parent = block;
  }
}
