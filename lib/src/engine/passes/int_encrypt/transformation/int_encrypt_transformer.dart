import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel/runtime_helpers.dart';
import 'package:refractor/src/engine/kernel_toolkit/traversal/scoped_transformer.dart';
import 'package:refractor/src/engine/pass/transformation/pass_transformer.dart';
import 'package:refractor/src/engine/passes/int_encrypt/planning/int_encrypt_plan.dart';
import 'package:refractor/src/engine/passes/int_encrypt/runtime/int_decode_runtime.dart';
import 'package:refractor/src/engine/passes/int_encrypt/transformation/int_encrypt_transform_output.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

class IntEncryptTransformer
    implements PassTransformer<IntEncryptPlan, IntEncryptTransformOutput> {
  IntEncryptTransformer({
    required ObfuscationScope scope,
    required RuntimeHelpers helpers,
  }) : _scope = scope,
       _helpers = helpers;

  final ObfuscationScope _scope;
  final RuntimeHelpers _helpers;

  @override
  Future<IntEncryptTransformOutput> apply(
    Component component,
    IntEncryptPlan plan,
  ) async {
    if (plan.plannedLiteralCount == 0) {
      return const IntEncryptTransformOutput(encryptedCount: 0);
    }

    final decodeProcedure = _helpers.require(intDecodeRuntimeHelperName);

    final visitor = _IntEncryptVisitor(
      decodeProcedure: decodeProcedure,
      scope: _scope,
      plan: plan,
    );
    component.transformChildren(visitor);
    return IntEncryptTransformOutput(encryptedCount: visitor.encryptedCount);
  }
}

final class _IntEncryptVisitor extends ScopedKernelTransformer {
  _IntEncryptVisitor({
    required this.decodeProcedure,
    required this.plan,
    required super.scope,
  });

  final Procedure decodeProcedure;
  final IntEncryptPlan plan;

  int encryptedCount = 0;

  @override
  TreeNode visitIntLiteral(IntLiteral node) {
    final rewrite = plan.rewriteFor(node);
    if (rewrite == null) {
      return node;
    }

    encryptedCount++;
    return StaticInvocation(
      decodeProcedure,
      Arguments([IntLiteral(rewrite.encoded), IntLiteral(rewrite.key)]),
    );
  }
}
