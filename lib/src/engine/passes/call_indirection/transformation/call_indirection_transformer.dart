import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel/injected_helpers.dart';
import 'package:refractor/src/engine/kernel_toolkit/traversal/scoped_transformer.dart';
import 'package:refractor/src/engine/pass/transformation/pass_transformer.dart';
import 'package:refractor/src/engine/passes/call_indirection/planning/call_indirection_plan.dart';
import 'package:refractor/src/engine/passes/call_indirection/runtime/call_indirection_runtime.dart';
import 'package:refractor/src/engine/passes/call_indirection/transformation/call_indirection_transform_output.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Rewrites each planned direct static call `f(a, b)` into
/// `refractorCall(f, [a, b]) as R`, routing it through the injected
/// never-inline forwarder. Void (and dynamic) results need no cast.
class CallIndirectionTransformer
    implements
        PassTransformer<CallIndirectionPlan, CallIndirectionTransformOutput> {
  CallIndirectionTransformer({
    required ObfuscationScope scope,
  }) : _scope = scope;

  final ObfuscationScope _scope;

  @override
  Future<CallIndirectionTransformOutput> apply(
    Component component,
    CallIndirectionPlan plan,
  ) async {
    if (plan.plannedSiteCount == 0) {
      return const CallIndirectionTransformOutput(indirectedCount: 0);
    }

    final forwarder = _resolveForwarder(component);
    if (forwarder == null) {
      return const CallIndirectionTransformOutput(indirectedCount: 0);
    }

    final visitor = _CallIndirectionVisitor(
      forwarder: forwarder,
      scope: _scope,
      plan: plan,
    );
    component.transformChildren(visitor);
    return CallIndirectionTransformOutput(
      indirectedCount: visitor.indirectedCount,
    );
  }

  Procedure? _resolveForwarder(Component component) =>
      InjectedHelpers.resolve(component, callIndirectionHelperName);
}

final class _CallIndirectionVisitor extends ScopedKernelTransformer {
  _CallIndirectionVisitor({
    required this.forwarder,
    required this.plan,
    required super.scope,
  });

  final Procedure forwarder;
  final CallIndirectionPlan plan;

  int indirectedCount = 0;

  @override
  TreeNode visitStaticInvocation(StaticInvocation node) {
    // Rewrite nested calls in the arguments first, then this call; the node
    // keeps its identity through child transformation, so the plan lookup
    // stays valid.
    node.transformChildren(this);
    if (!plan.contains(node)) {
      return node;
    }

    indirectedCount++;
    final target = node.target;
    final forwarded = StaticInvocation(
      forwarder,
      Arguments([
        // The VM only accepts static tear-offs as constants: the CFE always
        // lowers `f` to `ConstantExpression(StaticTearOffConstant(f))`, and
        // neither the JIT reader nor AOT type-flow analysis handles a bare
        // `StaticTearOff` expression.
        ConstantExpression(
          StaticTearOffConstant(target),
          target.function.computeFunctionType(Nullability.nonNullable),
        ),
        ListLiteral(node.arguments.positional),
      ]),
    );

    final returnType = target.function.returnType;
    if (returnType is VoidType || returnType is DynamicType) {
      return forwarded;
    }
    return AsExpression(forwarded, returnType);
  }
}
