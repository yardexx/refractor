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
///
/// Two statement kinds need more than a verbatim copy into a case:
///
/// * A local [VariableDeclaration] is hoisted ahead of the switch (where it
///   stays in scope for every case) and its initializer becomes a plain
///   assignment in the case that held it. Order preservation guarantees the
///   assignment still runs before any read.
/// * A [ReturnStatement] exits the whole function, so its case carries no
///   continue/break terminator — control never falls through to another case.
final class ControlFlowFlattenTransformer
    implements
        PassTransformer<
          ControlFlowFlattenPlan,
          ControlFlowFlattenTransformOutput
        > {
  const ControlFlowFlattenTransformer();

  @override
  ControlFlowFlattenTransformOutput apply(
    Component component,
    ControlFlowFlattenPlan plan,
  ) {
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

    // Declarations are hoisted so they stay in scope across every case; the
    // per-statement `action` is what that case actually runs (an assignment in
    // place of a declaration-with-initializer).
    final hoisted = <VariableDeclaration>[];
    final actions = <Statement>[
      for (final statement in statements) _prepare(statement, hoisted),
    ];

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
      final isReturn = statements[i] is ReturnStatement;
      final caseStatements = isReturn
          // A return exits the function; no continue/break follows it.
          ? [actions[i]]
          : [
              actions[i],
              if (i < statements.length - 1)
                ContinueSwitchStatement(cases[i + 1])
              else
                BreakStatement(label),
            ];
      cases[i].body = Block(caseStatements)..parent = cases[i];
    }

    final body = hoisted.isEmpty ? label : Block([...hoisted, label]);
    function.body = body..parent = function;
  }

  /// Returns the statement a case should run for [statement], recording any
  /// hoisted declaration in [hoisted].
  ///
  /// For a [VariableDeclaration] the declaration itself is moved into [hoisted]
  /// (stripped of its initializer and of `final`, which would forbid the later
  /// assignment) and the case runs `v = <initializer>` instead; a declaration
  /// without an initializer leaves an empty case. Every other statement runs
  /// as-is.
  Statement _prepare(Statement statement, List<VariableDeclaration> hoisted) {
    if (statement is! VariableDeclaration) {
      return statement;
    }
    final initializer = statement.initializer;
    statement
      ..initializer = null
      ..isFinal = false;
    hoisted.add(statement);
    if (initializer == null) {
      return EmptyStatement();
    }
    return ExpressionStatement(VariableSet(statement, initializer));
  }
}
