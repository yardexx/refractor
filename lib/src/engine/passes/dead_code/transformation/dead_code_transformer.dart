import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/builder/kernel_builder.dart';
import 'package:refractor/src/engine/pass/transformation/pass_transformer.dart';
import 'package:refractor/src/engine/passes/dead_code/planning/dead_code_plan.dart';
import 'package:refractor/src/engine/passes/dead_code/planning/planned_dead_code.dart';
import 'package:refractor/src/engine/passes/dead_code/transformation/dead_code_transform_output.dart';

/// Inserts a guarded dead-code block into each planned function body.
///
/// The guard is always false — `(v & mask) * (v & mask) < -bound`, a masked
/// square that never goes negative — so the block never runs and behaviour is
/// unchanged. It reads a live `int` in scope at the insertion point (a
/// parameter at the start of the body, or a local just after its declaration),
/// so it is not a compile-time constant and cannot be folded away.
///
/// The block seeds a temporary from `v`, applies the planned junk steps to it
/// and hands the result to a sink — writing it back into `v`, returning it, or
/// throwing it. The sink is what keeps the block alive in an AOT build: junk
/// whose result is discarded is pure, so the compiler deletes it and then the
/// empty `if`.
final class DeadCodeTransformer
    implements PassTransformer<DeadCodePlan, DeadCodeTransformOutput> {
  const DeadCodeTransformer();

  @override
  DeadCodeTransformOutput apply(
    Component component,
    DeadCodePlan plan,
  ) {
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
        builder.bitAnd(ref(), builder.intLit(decision.mask)),
        builder.bitAnd(ref(), builder.intLit(decision.mask)),
      ),
      builder.intLit(-decision.bound),
    );

    final first = decision.steps.first;
    final temp = VariableDeclaration(
      null,
      initializer: _apply(builder, first, ref(), ref),
      type: builder.intType,
      isSynthesized: true,
    );
    final deadBlock = Block([
      temp,
      for (final step in decision.steps.skip(1))
        ExpressionStatement(
          VariableSet(temp, _apply(builder, step, VariableGet(temp), ref)),
        ),
      switch (decision.sink) {
        DeadCodeSink.reassign => ExpressionStatement(
          VariableSet(variable, VariableGet(temp)),
        ),
        DeadCodeSink.returnValue => ReturnStatement(VariableGet(temp)),
        DeadCodeSink.throwValue => ExpressionStatement(
          Throw(VariableGet(temp)),
        ),
      },
    ]);

    final guardedIf = IfStatement(guard, deadBlock, null);
    block.statements.insert(decision.site.insertionIndex, guardedIf);
    guardedIf.parent = block;
  }

  Expression _apply(
    KernelBuilder builder,
    DeadCodeStep step,
    Expression target,
    Expression Function() variable,
  ) {
    final operand = step.usesVariable
        ? variable()
        : builder.intLit(step.constant);
    return switch (step.op) {
      DeadCodeOp.add => builder.add(target, operand),
      DeadCodeOp.sub => builder.sub(target, operand),
      DeadCodeOp.mul => builder.mul(target, operand),
      DeadCodeOp.xor => builder.xor(target, operand),
      DeadCodeOp.and => builder.bitAnd(target, operand),
      DeadCodeOp.shl => builder.shl(target, operand),
    };
  }
}
