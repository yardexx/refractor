import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/pass_transformer.dart';

class DeadCodeTransformer extends PassTransformer {
  DeadCodeTransformer({
    required this.intClass,
    required this.maxInsertions,
    required super.context,
  });

  final int maxInsertions;
  final Class intClass;

  @override
  TreeNode visitProcedure(Procedure node) {
    if (_isFunctionEmpty(node)) return super.visitProcedure(node);

    final body = node.function.body;
    if (body is! Block) return super.visitProcedure(node);

    final newStatements = <Statement>[];
    var insertions = 0;

    for (final statement in body.statements) {
      if (insertions < maxInsertions) {
        newStatements.add(_buildDeadBranch());
        insertions++;
      }
      newStatements.add(statement);
    }

    if (insertions > 0) {
      node.function.body = Block(newStatements)..parent = node.function;
    }

    return super.visitProcedure(node);
  }

  /// Checks if the procedure's body is empty or not a block.
  /// ```dart
  /// void foo() {} // empty body
  /// void bar() => print('hi'); // not a block body
  /// ```
  bool _isFunctionEmpty(Procedure node) {
    final body = node.function.body;
    return body is! Block || body.statements.isEmpty;
  }

  /// Builds the kernel equivalent of:
  /// ```dart
  /// if (false) {
  ///   var _d = 0;
  ///   _d = _d + 1;
  /// }
  /// ```
  Statement _buildDeadBranch() {
    final intType = InterfaceType(intClass, Nullability.nullable);

    // var _d = 0;
    final dummy = VariableDeclaration(
      '_d',
      initializer: IntLiteral(0),
      type: intType,
    );

    // _d = _d + 1;
    final dummyAssignment = ExpressionStatement(
      VariableSet(dummy, IntLiteral(1)),
    );

    // if (false) { ... }
    final dummyIf = IfStatement(
      BoolLiteral(false), // condition: always false
      Block([dummy, dummyAssignment]), // then branch with dummy code
      null, // no else branch
    );

    return dummyIf;
  }
}
