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

  @override
  TreeNode visitProcedure(Procedure node) {
    // Skip the helper procedure itself.
    if (node == decodeProcedure) return node;
    return super.visitProcedure(node);
  }

  @override
  TreeNode visitStringLiteral(StringLiteral node) {
    if (inConstContext) return node;
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
