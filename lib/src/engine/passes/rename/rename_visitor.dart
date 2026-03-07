import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/pass_visitor.dart';
import 'package:refractor/src/engine/passes/rename/rename_helpers.dart';

class RenameVisitor extends PassVisitor {
  RenameVisitor({
    required super.context,
    this.preMemberRenames = const {},
  });

  /// Pre-computed member renames from override family analysis.
  final Map<Member, Name> preMemberRenames;

  /// Maps class nodes to their new name strings.
  final Map<Class, String> classRenames = {};

  /// Maps member nodes (Field, Procedure, Constructor) to their new Name.
  final Map<Member, Name> memberRenames = {};
  final Map<VariableDeclaration, String> variableRenames = {};

  @override
  void visitClass(Class node) {
    if (hasEntryPointPragma(node.annotations)) {
      super.visitClass(node);
      return;
    }
    if (node.name.isNotEmpty) {
      final obf = context.nameGenerator.next();
      context.symbolTable.record(node.name, obf);
      classRenames[node] = obf;
    }
    super.visitClass(node);
  }

  @override
  void visitProcedure(Procedure node) {
    if (hasEntryPointPragma(node.annotations)) {
      super.visitProcedure(node);
      return;
    }
    final n = node.name.text;
    if (context.options.preserveMain && n == 'main') {
      super.visitProcedure(node);
      return;
    }
    // Use pre-computed rename if available, otherwise skip
    // (top-level procedures are also pre-computed by the analyzer).
    final precomputed = preMemberRenames[node];
    if (precomputed != null) {
      memberRenames[node] = precomputed;
    }
    super.visitProcedure(node);
  }

  @override
  void visitField(Field node) {
    if (hasEntryPointPragma(node.annotations)) return;
    final precomputed = preMemberRenames[node];
    if (precomputed != null) {
      memberRenames[node] = precomputed;
    }
  }

  @override
  void visitConstructor(Constructor node) {
    if (hasEntryPointPragma(node.annotations)) {
      super.visitConstructor(node);
      return;
    }
    final precomputed = preMemberRenames[node];
    if (precomputed != null) {
      memberRenames[node] = precomputed;
    }
    super.visitConstructor(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final originalName = node.name;
    if (originalName != null && originalName.isNotEmpty) {
      final obf = context.nameGenerator.next();
      context.symbolTable.record(originalName, obf);
      variableRenames[node] = obf;
    }
    super.visitVariableDeclaration(node);
  }
}
