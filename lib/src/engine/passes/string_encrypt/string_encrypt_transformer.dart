import 'dart:math';

import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/scoped_kernel_transformer.dart';
import 'package:refractor/src/engine/passes/string_encrypt/string_encrypt_pass.dart';
import 'package:refractor/src/policy/string_encrypt_policy_view.dart';
import 'package:refractor/src/project/project_scope.dart';

class StringEncryptTransformer {
  StringEncryptTransformer({
    required Procedure decodeProcedure,
    required Random random,
    required ProjectScope projectScope,
    required StringEncryptPolicyView policy,
    this.excludePatterns = const [],
  }) : _decodeProcedure = decodeProcedure,
       _random = random,
       _projectScope = projectScope,
       _policy = policy;

  final Procedure _decodeProcedure;
  final Random _random;
  final ProjectScope _projectScope;
  final StringEncryptPolicyView _policy;
  final List<RegExp> excludePatterns;

  int apply(Component component) {
    final visitor = _StringEncryptVisitor(
      decodeProcedure: _decodeProcedure,
      random: _random,
      projectScope: _projectScope,
      policy: _policy,
      excludePatterns: excludePatterns,
    );
    component.transformChildren(visitor);
    return visitor.encryptedCount;
  }
}

final class _StringEncryptVisitor extends ScopedKernelTransformer {
  _StringEncryptVisitor({
    required this.decodeProcedure,
    required this.random,
    required super.projectScope,
    required this.policy,
    required this.excludePatterns,
  });

  final Procedure decodeProcedure;
  final Random random;
  final StringEncryptPolicyView policy;
  final List<RegExp> excludePatterns;

  int encryptedCount = 0;

  @override
  TreeNode visitClass(Class node) {
    if (policy.isClassKept(node)) {
      return node;
    }
    return super.visitClass(node);
  }

  @override
  TreeNode visitProcedure(Procedure node) {
    if (node == decodeProcedure) return node;
    if (policy.isMemberKept(node)) {
      return node;
    }
    return super.visitProcedure(node);
  }

  @override
  TreeNode visitField(Field node) {
    if (policy.isMemberKept(node)) {
      return node;
    }
    return super.visitField(node);
  }

  @override
  TreeNode visitConstructor(Constructor node) {
    if (policy.isMemberKept(node)) {
      return node;
    }
    return super.visitConstructor(node);
  }

  @override
  TreeNode visitStringLiteral(StringLiteral node) {
    if (inConstContext) return node;
    for (final pattern in excludePatterns) {
      if (pattern.hasMatch(node.value)) return node;
    }

    final key = random.nextInt(0xFFFFFFFF) + 1;
    final encoded = StringEncryptPass.encodeWithKey(node.value, key);
    encryptedCount++;

    return StaticInvocation(
      decodeProcedure,
      Arguments([
        ListLiteral(
          encoded.map((b) => IntLiteral(b) as Expression).toList(),
        ),
        IntLiteral(key),
      ]),
    );
  }
}
