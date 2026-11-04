import 'package:kernel/ast.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Scope gating and const/annotation tracking for selector [RecursiveVisitor]s
/// (the read-only analogue of `ScopedKernelTransformer` for the mutation side).
mixin ScopedVisiting on RecursiveVisitor {
  ObfuscationScope get scope;

  int _constDepth = 0;
  int _annotationDepth = 0;

  /// Literals reached inside a const expression or an annotation are part of a
  /// const context, not runtime values, so passes must leave them alone.
  bool get inConstContext => _constDepth > 0 || _annotationDepth > 0;

  bool isScopedLibrary(Library node) => scope.shouldObfuscateLibrary(node);

  bool isScopedClass(Class node) => scope.shouldObfuscateClass(node);

  bool isScopedMember(Member node) => scope.shouldObfuscateMember(node);

  void visitAnnotations(List<Expression> annotations) {
    _annotationDepth++;
    try {
      for (final annotation in annotations) {
        annotation.accept(this);
      }
    } finally {
      _annotationDepth--;
    }
  }

  @override
  void visitConstantExpression(ConstantExpression node) {
    _constDepth++;
    try {
      super.visitConstantExpression(node);
    } finally {
      _constDepth--;
    }
  }
}
