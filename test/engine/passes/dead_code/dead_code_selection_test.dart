import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/dead_code/selection/dead_code_selection.dart';
import 'package:test/test.dart';

void main() {
  final intType = InterfaceType(
    Class(name: 'int', fileUri: Uri.parse('dart:core')),
    Nullability.nonNullable,
  );

  VariableDeclaration intParam() => VariableDeclaration('p', type: intType);
  VariableDeclaration dynParam() => VariableDeclaration('x');
  FunctionNode function(
    List<VariableDeclaration> params, {
    Statement? body,
  }) {
    return FunctionNode(body ?? Block([]), positionalParameters: params);
  }

  group('isDeadCodeTarget / firstIntParam', () {
    test('a block body with an int parameter is a target', () {
      final node = function([intParam()]);
      expect(isDeadCodeTarget(node), isTrue);
      expect(firstIntParam(node), isNotNull);
    });

    test('no int parameter is not a target', () {
      expect(firstIntParam(function([dynParam()])), isNull);
      expect(isDeadCodeTarget(function([dynParam()])), isFalse);
      expect(isDeadCodeTarget(function([])), isFalse);
    });

    test('a non-block body is not a target', () {
      expect(
        isDeadCodeTarget(function([intParam()], body: ReturnStatement())),
        isFalse,
      );
    });
  });
}
