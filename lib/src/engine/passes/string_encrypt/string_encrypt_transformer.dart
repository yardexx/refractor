import 'dart:math';

import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/pass_transformer.dart';
import 'package:refractor/src/engine/passes/string_encrypt/string_encrypt_pass.dart';

class StringEncryptTransformer extends PassTransformer {
  StringEncryptTransformer({
    required this.decodeProcedure,
    required this.random,
    required super.target,
    this.excludePatterns = const [],
  });

  final Procedure decodeProcedure;
  final Random random;
  final List<RegExp> excludePatterns;
  int count = 0;

  // Track whether we're inside a const context or annotation.
  int _constDepth = 0;
  int _annotationDepth = 0;

  bool get _inConstContext => _constDepth > 0 || _annotationDepth > 0;

  void _transformAnnotations(List<Expression> annotations) {
    _annotationDepth++;
    try {
      for (var i = 0; i < annotations.length; i++) {
        annotations[i] = annotations[i].accept(this) as Expression;
      }
    } finally {
      _annotationDepth--;
    }
  }

  @override
  TreeNode visitClass(Class node) {
    _transformAnnotations(node.annotations);
    // Transform the rest of the class normally.
    node.transformChildren(this);
    return node;
  }

  @override
  TreeNode visitProcedure(Procedure node) {
    // Skip the helper procedure itself.
    if (node == decodeProcedure) return node;

    _transformAnnotations(node.annotations);

    // Transform function body normally.
    node.function = node.function.accept(this) as FunctionNode;
    return node;
  }

  @override
  TreeNode visitField(Field node) {
    _transformAnnotations(node.annotations);
    node.transformChildren(this);
    return node;
  }

  @override
  TreeNode visitConstructor(Constructor node) {
    _transformAnnotations(node.annotations);
    node.transformChildren(this);
    return node;
  }

  @override
  TreeNode visitConstantExpression(ConstantExpression node) {
    _constDepth++;
    try {
      return super.visitConstantExpression(node);
    } finally {
      _constDepth--;
    }
  }

  @override
  TreeNode visitStringLiteral(StringLiteral node) {
    if (_inConstContext) return node;
    for (final pattern in excludePatterns) {
      if (pattern.hasMatch(node.value)) return node;
    }

    final key = random.nextInt(0xFFFFFFFF) + 1;
    final encoded = StringEncryptPass.encodeWithKey(node.value, key);
    count++;

    // Build: _obfDecode$([encoded bytes], per-string key)
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
