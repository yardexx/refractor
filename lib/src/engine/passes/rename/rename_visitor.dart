import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/pass_visitor.dart';

class RenameVisitor extends PassVisitor {
  RenameVisitor({required super.context});

  /// Maps class nodes to their new name strings.
  final Map<Class, String> classRenames = {};

  /// Maps member nodes (Field, Procedure) to their new Name.
  /// Uses member identity so lookups work even after the member's name is
  /// mutated.
  final Map<Member, Name> memberRenames = {};
  final Map<VariableDeclaration, String> variableRenames = {};

  /// Tracks assigned names per library to deduplicate (e.g., field `appName`
  /// and getter `appName` in the same lib should get the same obfuscated name).
  final Map<String, String> _nameDedup = {};

  @override
  void visitClass(Class node) {
    if (_hasEntryPointPragma(node.annotations)) {
      super.visitClass(node);
      return;
    }
    if (_shouldRename(node.name)) {
      final lib = node.enclosingLibrary;
      final key = 'class:${lib.importUri}:${node.name}';
      final obf = _nameDedup.putIfAbsent(key, () {
        final o = context.nameGenerator.next();
        context.symbolTable.record(node.name, o);
        return o;
      });
      classRenames[node] = obf;
    }
    super.visitClass(node);
  }

  @override
  void visitProcedure(Procedure node) {
    if (_hasEntryPointPragma(node.annotations)) {
      super.visitProcedure(node);
      return;
    }
    final n = node.name.text;
    if (context.options.preserveMain && n == 'main') {
      super.visitProcedure(node);
      return;
    }
    if (_shouldRename(n)) {
      final lib = node.enclosingLibrary;
      final obf = _assignMemberName(lib, n);
      final nameLib = obf.startsWith('_') ? lib : node.name.library;
      memberRenames[node] = Name(obf, nameLib);
    }
    super.visitProcedure(node);
  }

  @override
  void visitField(Field node) {
    if (_hasEntryPointPragma(node.annotations)) return;
    if (_shouldRename(node.name.text)) {
      final lib = node.enclosingLibrary;
      final obf = _assignMemberName(lib, node.name.text);
      final nameLib = obf.startsWith('_') ? lib : node.name.library;
      memberRenames[node] = Name(obf, nameLib);
    }
  }

  @override
  void visitConstructor(Constructor node) {
    if (_hasEntryPointPragma(node.annotations)) {
      super.visitConstructor(node);
      return;
    }
    final n = node.name.text;
    if (_shouldRename(n)) {
      final lib = node.enclosingLibrary;
      final obf = _assignMemberName(lib, n);
      final nameLib = obf.startsWith('_') ? lib : node.name.library;
      memberRenames[node] = Name(obf, nameLib);
    }
    super.visitConstructor(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final originalName = node.name;
    if (originalName != null && _shouldRename(originalName)) {
      final obf = context.nameGenerator.next();
      context.symbolTable.record(originalName, obf);
      variableRenames[node] = obf;
    }
    super.visitVariableDeclaration(node);
  }

  bool _shouldRename(String name) {
    if (name.isEmpty) return false;

    return true;
  }

  bool _hasEntryPointPragma(List<Expression> annotations) {
    for (final ann in annotations) {
      if (ann is ConstantExpression) {
        final c = ann.constant;
        if (c is InstanceConstant) {
          if (c.classNode.name == 'pragma') return true;
        }
      }
    }
    return false;
  }

  /// Deduplication key for members in the same library.
  String _dedupKey(Library lib, String name) => 'member:${lib.importUri}:$name';

  /// Assign (or reuse) an obfuscated name for a member in [lib].
  String _assignMemberName(Library lib, String originalName) {
    final key = _dedupKey(lib, originalName);
    return _nameDedup.putIfAbsent(key, () {
      final obf = context.nameGenerator.next();
      context.symbolTable.record(originalName, obf);
      return obf;
    });
  }
}
