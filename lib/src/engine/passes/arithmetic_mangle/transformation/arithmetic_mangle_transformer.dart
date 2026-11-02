import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/builder/kernel_builder.dart';
import 'package:refractor/src/engine/kernel_toolkit/traversal/scoped_transformer.dart';
import 'package:refractor/src/engine/pass/transformation/pass_transformer.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/mangle/arithmetic_mangle_rules.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/planning/arithmetic_mangle_plan.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/transformation/arithmetic_mangle_transform_output.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Replaces each planned integer `+`/`*` with an equivalent mangled expression.
final class ArithmeticMangleTransformer
    implements
        PassTransformer<ArithmeticManglePlan, ArithmeticMangleTransformOutput> {
  ArithmeticMangleTransformer({required ObfuscationScope scope})
    : _scope = scope;

  final ObfuscationScope _scope;

  @override
  ArithmeticMangleTransformOutput apply(
    Component component,
    ArithmeticManglePlan plan,
  ) {
    if (plan.decisionCount == 0) {
      return const ArithmeticMangleTransformOutput(mangledCount: 0);
    }

    final visitor = _ArithmeticMangleVisitor(
      scope: _scope,
      plan: plan,
      builder: KernelBuilder(component),
    );
    component.transformChildren(visitor);
    return ArithmeticMangleTransformOutput(mangledCount: visitor.mangledCount);
  }
}

final class _ArithmeticMangleVisitor extends ScopedKernelTransformer {
  _ArithmeticMangleVisitor({
    required super.scope,
    required this.plan,
    required this.builder,
  });

  final ArithmeticManglePlan plan;
  final KernelBuilder builder;

  int mangledCount = 0;

  @override
  TreeNode visitInstanceInvocation(InstanceInvocation node) {
    // Mangle nested operands first, so a site sees its mangled children.
    node.transformChildren(this);

    final decision = plan.decisionFor(node);
    if (decision == null) {
      return node;
    }

    // Bind each operand to a temporary so it is evaluated exactly once; the
    // mangled expression then reads the temporaries, never re-evaluating the
    // original (possibly side-effecting) operand.
    final left = VariableDeclaration.forValue(
      node.receiver,
      type: builder.intType,
    );
    final right = VariableDeclaration.forValue(
      node.arguments.positional.first,
      type: builder.intType,
    );
    Expression refLeft() => VariableGet(left);
    Expression refRight() => VariableGet(right);

    final mangled = node.name.text == '+'
        ? mangleAddition(builder, refLeft, refRight, decision.constant)
        : mangleMultiplication(builder, refLeft, refRight, decision.constant);

    mangledCount++;
    // The generated expression contains new `+`/`*` nodes, but they are not in
    // the plan and this replacement is not re-visited, so they are never
    // re-mangled.
    return Let(left, Let(right, mangled));
  }
}
