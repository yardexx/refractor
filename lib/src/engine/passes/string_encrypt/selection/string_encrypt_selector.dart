import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/traversal/scoped_visiting.dart';
import 'package:refractor/src/engine/pass/selection/pass_selector.dart';
import 'package:refractor/src/engine/passes/string_encrypt/selection/string_encrypt_selection.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

final class StringEncryptSelector
    implements PassSelector<StringEncryptSelection> {
  StringEncryptSelector({
    required ObfuscationScope scope,
    required List<RegExp> excludedLiteralPatterns,
  }) : _scope = scope,
       _excludedLiteralPatterns = excludedLiteralPatterns;

  final ObfuscationScope _scope;
  final List<RegExp> _excludedLiteralPatterns;

  @override
  StringEncryptSelection select(Component component) {
    final collector = _StringEncryptSelectionCollector(
      scope: _scope,
      excludedLiteralPatterns: _excludedLiteralPatterns,
    );
    component.accept(collector);
    return collector.build();
  }
}

final class _StringEncryptSelectionCollector extends RecursiveVisitor
    with ScopedVisiting {
  _StringEncryptSelectionCollector({
    required this.scope,
    required List<RegExp> excludedLiteralPatterns,
  }) : _excludedLiteralPatterns = excludedLiteralPatterns;

  @override
  final ObfuscationScope scope;

  final List<RegExp> _excludedLiteralPatterns;
  final List<StringLiteral> _selectedStringLiterals = <StringLiteral>[];
  final Set<StringLiteral> _selectedStringLiteralSet = <StringLiteral>{};

  StringEncryptSelection build() {
    return StringEncryptSelection(
      orderedLiterals: _selectedStringLiterals,
    );
  }

  @override
  void visitLibrary(Library node) {
    if (!isScopedLibrary(node)) {
      return;
    }
    super.visitLibrary(node);
  }

  @override
  void visitClass(Class node) {
    visitAnnotations(node.annotations);
    if (!isScopedClass(node)) {
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
    visitAnnotations(node.annotations);
    if (!isScopedMember(node)) {
      return;
    }
    node.function.accept(this);
  }

  @override
  void visitField(Field node) {
    visitAnnotations(node.annotations);
    if (!isScopedMember(node)) {
      return;
    }
    node.initializer?.accept(this);
  }

  @override
  void visitConstructor(Constructor node) {
    visitAnnotations(node.annotations);
    if (!isScopedMember(node)) {
      return;
    }
    for (final initializer in node.initializers) {
      initializer.accept(this);
    }
    node.function.accept(this);
  }

  @override
  void visitStringLiteral(StringLiteral node) {
    if (inConstContext) {
      return;
    }
    if (node.value.isEmpty) {
      return;
    }
    if (_isExcludedLiteral(node.value)) {
      return;
    }
    if (_selectedStringLiteralSet.add(node)) {
      _selectedStringLiterals.add(node);
    }
  }

  bool _isExcludedLiteral(String value) {
    for (final pattern in _excludedLiteralPatterns) {
      if (pattern.hasMatch(value)) {
        return true;
      }
    }
    return false;
  }
}
