import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/traversal/scoped_visiting.dart';
import 'package:refractor/src/engine/pass/selection/pass_selector.dart';
import 'package:refractor/src/engine/passes/int_encrypt/selection/int_encrypt_selection.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

final class IntEncryptSelector implements PassSelector<IntEncryptSelection> {
  IntEncryptSelector({
    required ObfuscationScope scope,
    required int minMagnitude,
  }) : _scope = scope,
       _minMagnitude = minMagnitude;

  final ObfuscationScope _scope;
  final int _minMagnitude;

  @override
  IntEncryptSelection select(Component component) {
    final collector = _IntEncryptSelectionCollector(
      scope: _scope,
      minMagnitude: _minMagnitude,
    );
    component.accept(collector);
    return collector.build();
  }
}

final class _IntEncryptSelectionCollector extends RecursiveVisitor
    with ScopedVisiting {
  _IntEncryptSelectionCollector({
    required this.scope,
    required int minMagnitude,
  }) : _minMagnitude = minMagnitude;

  @override
  final ObfuscationScope scope;

  final int _minMagnitude;
  final List<IntLiteral> _selectedLiterals = <IntLiteral>[];
  final Set<IntLiteral> _selectedLiteralSet = Set<IntLiteral>.identity();

  IntEncryptSelection build() {
    return IntEncryptSelection(orderedLiterals: _selectedLiterals);
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
  void visitIntLiteral(IntLiteral node) {
    if (inConstContext) {
      return;
    }
    // Skip the ubiquitous trivial constants (controlled by minMagnitude) so the
    // pass does not rewrite every loop counter and array index into a call.
    if (node.value.abs() < _minMagnitude) {
      return;
    }
    if (_selectedLiteralSet.add(node)) {
      _selectedLiterals.add(node);
    }
  }
}
