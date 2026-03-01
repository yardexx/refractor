import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/pass_transformer.dart';
import 'package:refractor/src/engine/passes/string_encrypt/string_encrypt_pass.dart';

class StringEncryptTransformer extends PassTransformer {
  StringEncryptTransformer({
    required this.decodeProcedure,
    // TODO(user): Consider using an object which encapsulates random
    // generation and encoding logic, to support multiple algorithms.
    required this.xorKey,
    required super.context,
  });

  final Procedure decodeProcedure;
  final int xorKey;
  int count = 0;

  // Track whether we're inside a const context or annotation.
  int _constDepth = 0;
  int _annotationDepth = 0;

  bool get _inConstContext => _constDepth > 0 || _annotationDepth > 0;

  @override
  TreeNode visitClass(Class node) {
    // Skip annotation processing on class annotations to avoid encrypting them.
    _annotationDepth++;
    for (var i = 0; i < node.annotations.length; i++) {
      node.annotations[i] = node.annotations[i].accept(this) as Expression;
    }
    _annotationDepth--;
    // Transform the rest of the class normally.
    node.transformChildren(this);
    return node;
  }

  @override
  TreeNode visitProcedure(Procedure node) {
    // Skip the helper procedure itself.
    if (node == decodeProcedure) return node;

    // Don't encrypt annotation arguments.
    _annotationDepth++;
    for (var i = 0; i < node.annotations.length; i++) {
      node.annotations[i] = node.annotations[i].accept(this) as Expression;
    }
    _annotationDepth--;

    // Transform function body normally.
    node.function = node.function.accept(this) as FunctionNode;
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

    // Huh?
    final pass = StringEncryptPass(xorKey: xorKey);
    final encoded = pass.encode(node.value);
    count++;

    // Build: _obfDecode$([encoded bytes], xorKey)
    return StaticInvocation(
      decodeProcedure,
      Arguments([
        ListLiteral(
          encoded.map((b) => IntLiteral(b) as Expression).toList(),
        ),
        IntLiteral(xorKey),
      ]),
    );
  }
}
