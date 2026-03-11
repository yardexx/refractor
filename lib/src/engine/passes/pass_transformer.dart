import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/runner/obfuscation_target.dart';

abstract class PassTransformer extends Transformer {
  PassTransformer({required this.target});

  final ObfuscationTarget target;

  @override
  TreeNode visitLibrary(Library node) {
    if (!target.shouldObfuscateLibrary(node)) return node;
    return super.visitLibrary(node);
  }
}
