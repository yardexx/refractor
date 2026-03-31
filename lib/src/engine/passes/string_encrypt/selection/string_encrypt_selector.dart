import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/selection/pass_selector.dart';
import 'package:refractor/src/engine/passes/string_encrypt/selection/string_encrypt_selection.dart';
import 'package:refractor/src/policy/string_encrypt_policy_view.dart';
import 'package:refractor/src/project/project_scope.dart';

final class StringEncryptSelector
    implements PassSelector<StringEncryptSelection> {
  StringEncryptSelector({
    required ProjectScope projectScope,
    required StringEncryptPolicyView policy,
    required Procedure decodeProcedure,
    required List<RegExp> excludePatterns,
  }) : _projectScope = projectScope,
       _policy = policy,
       _decodeProcedure = decodeProcedure,
       _excludePatterns = excludePatterns;

  final ProjectScope _projectScope;
  final StringEncryptPolicyView _policy;
  final Procedure _decodeProcedure;
  final List<RegExp> _excludePatterns;

  @override
  StringEncryptSelection select(Component component) {
    final collector = _StringEncryptSelectionCollector(
      projectScope: _projectScope,
      policy: _policy,
      decodeProcedure: _decodeProcedure,
      excludePatterns: _excludePatterns,
    );
    component.accept(collector);
    return collector.build();
  }
}

final class _StringEncryptSelectionCollector extends RecursiveVisitor {
  _StringEncryptSelectionCollector({
    required ProjectScope projectScope,
    required StringEncryptPolicyView policy,
    required Procedure decodeProcedure,
    required List<RegExp> excludePatterns,
  }) : _projectScope = projectScope,
       _policy = policy,
       _decodeProcedure = decodeProcedure,
       _excludePatterns = excludePatterns;

  final ProjectScope _projectScope;
  final StringEncryptPolicyView _policy;
  final Procedure _decodeProcedure;
  final List<RegExp> _excludePatterns;
  final List<StringLiteral> _selectedStringLiterals = <StringLiteral>[];
  final Set<StringLiteral> _selectedStringLiteralSet = <StringLiteral>{};

  int _constDepth = 0;
  int _annotationDepth = 0;

  bool get _inConstContext => _constDepth > 0 || _annotationDepth > 0;

  StringEncryptSelection build() {
    return StringEncryptSelection(
      orderedLiterals: _selectedStringLiterals,
    );
  }

  @override
  void visitLibrary(Library node) {
    if (!_projectScope.containsLibrary(node)) {
      return;
    }
    if (_policy.isLibraryKept(node)) {
      return;
    }
    super.visitLibrary(node);
  }

  @override
  void visitClass(Class node) {
    _visitAnnotations(node.annotations);
    if (_policy.isClassKept(node)) {
      return;
    }
    for (final constructor in node.constructors) {
      constructor.accept(this);
    }
    for (final procedure in node.procedures) {
      procedure.accept(this);
    }
    for (final field in node.fields) {
      field.accept(this);
    }
  }

  @override
  void visitProcedure(Procedure node) {
    _visitAnnotations(node.annotations);
    if (node == _decodeProcedure) {
      return;
    }
    if (_policy.isMemberKept(node)) {
      return;
    }
    node.function.accept(this);
  }

  @override
  void visitField(Field node) {
    _visitAnnotations(node.annotations);
    if (_policy.isMemberKept(node)) {
      return;
    }
    node.initializer?.accept(this);
  }

  @override
  void visitConstructor(Constructor node) {
    _visitAnnotations(node.annotations);
    if (_policy.isMemberKept(node)) {
      return;
    }
    for (final initializer in node.initializers) {
      initializer.accept(this);
    }
    node.function.accept(this);
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

  @override
  void visitStringLiteral(StringLiteral node) {
    if (_inConstContext) {
      return;
    }
    for (final pattern in _excludePatterns) {
      if (pattern.hasMatch(node.value)) {
        return;
      }
    }
    if (_selectedStringLiteralSet.add(node)) {
      _selectedStringLiterals.add(node);
    }
  }

  void _visitAnnotations(List<Expression> annotations) {
    _annotationDepth++;
    try {
      for (final annotation in annotations) {
        annotation.accept(this);
      }
    } finally {
      _annotationDepth--;
    }
  }
}
