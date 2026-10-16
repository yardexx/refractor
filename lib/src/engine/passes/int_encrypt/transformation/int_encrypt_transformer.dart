import 'package:kernel/ast.dart';
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
  }) : _scope = scope;

  final ObfuscationScope _scope;

  @override
  Future<IntEncryptTransformOutput> apply(
    Component component,
    IntEncryptPlan plan,
  ) async {
    if (plan.plannedLiteralCount == 0) {
      return const IntEncryptTransformOutput(encryptedCount: 0);
    }

    final decodeProcedure = _resolveDecodeProcedure(component);
    if (decodeProcedure == null) {
      return const IntEncryptTransformOutput(encryptedCount: 0);
    }

    final visitor = _IntEncryptVisitor(
      decodeProcedure: decodeProcedure,
      scope: _scope,
      plan: plan,
    );
    component.transformChildren(visitor);
    return IntEncryptTransformOutput(encryptedCount: visitor.encryptedCount);
  }

  /// Finds the decode helper the engine injected into the program. Returns null
  /// when it is absent, in which case no literal is rewritten.
  Procedure? _resolveDecodeProcedure(Component component) {
    for (final library in component.libraries) {
      for (final procedure in library.procedures) {
        if (procedure.name.text == intDecodeRuntimeHelperName) return procedure;
      }
    }
    return null;
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
