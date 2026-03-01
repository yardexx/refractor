import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/runner/pass_context.dart';

abstract class PassTransformer extends Transformer {
  PassTransformer({required this.context});

  final PassContext context;

  @override
  TreeNode visitLibrary(Library node) {
    if (!context.shouldObfuscateLibrary(node)) return node;
    return super.visitLibrary(node);
  }
}
