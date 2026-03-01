import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/runner/pass_context.dart';

class PassVisitor extends RecursiveVisitor {
  PassVisitor({required this.context});

  final PassContext context;

  @override
  void visitLibrary(Library node) {
    if (!context.shouldObfuscateLibrary(node)) return;
    super.visitLibrary(node);
  }
}
