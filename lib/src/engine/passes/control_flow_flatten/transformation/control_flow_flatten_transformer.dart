import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/builder/kernel_builder.dart';
import 'package:refractor/src/engine/pass/transformation/pass_transformer.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/planning/control_flow_flatten_plan.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/transformation/control_flow_flatten_transform_output.dart';

/// Rewrites each planned body into a switch-dispatch state machine.
///
/// The `n` statements become `n` switch cases (case value == original index).
/// The cases are laid out in the planned shuffled order, but each case ends by
/// jumping to the next original case via a labelled `continue`, so execution
/// order is unchanged; the last case breaks out of the switch. The body is
/// entered by switching on `0`.
final class ControlFlowFlattenTransformer
    implements
        PassTransformer<
          ControlFlowFlattenPlan,
          ControlFlowFlattenTransformOutput
        > {
  const ControlFlowFlattenTransformer();

  @override
  Future<ControlFlowFlattenTransformOutput> apply(
    Component component,
    ControlFlowFlattenPlan plan,
  ) async {
    if (plan.decisionCount == 0) {
      return const ControlFlowFlattenTransformOutput(flattenedCount: 0);
    }

    final builder = KernelBuilder(component);
    for (final decision in plan.decisions) {
      _flatten(decision.function, decision.layout, builder);
    }
    return ControlFlowFlattenTransformOutput(
      flattenedCount: plan.decisionCount,
    );
  }

  void _flatten(
    FunctionNode function,
    List<int> layout,
    KernelBuilder builder,
  ) {
    final statements = (function.body! as Block).statements;

    // One case per statement; case value == original index. Case labels must
    // be constants. Bodies are wired afterwards so a case can reference a later
    // case as its continue target.
    final cases = [
      for (var i = 0; i < statements.length; i++)
        SwitchCase(
          [ConstantExpression(IntConstant(i), builder.intType)],
          const [TreeNode.noOffset],
          null,
        ),
    ];

    final switchStatement = SwitchStatement(builder.intLit(0), [
      for (final index in layout) cases[index],
    ])..expressionType = builder.intType;
    final label = LabeledStatement(switchStatement);

    for (var i = 0; i < statements.length; i++) {
      final terminator = i < statements.length - 1
          ? ContinueSwitchStatement(cases[i + 1])
          : BreakStatement(label);
      cases[i].body = Block([statements[i], terminator])..parent = cases[i];
    }

    function.body = label..parent = function;
  }
}
