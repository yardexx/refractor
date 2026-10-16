import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/selection/control_flow_flatten_selection.dart';
import 'package:test/test.dart';

FunctionNode _function(
  Statement body, {
  AsyncMarker asyncMarker = AsyncMarker.Sync,
}) {
  return FunctionNode(body, asyncMarker: asyncMarker);
}

ExpressionStatement _expr() => ExpressionStatement(StringLiteral('x'));

VariableDeclaration _local({
  bool isLate = false,
  bool isConst = false,
}) {
  final declaration = VariableDeclaration(
    'v',
    initializer: IntLiteral(1),
    isConst: isConst,
  )..isLate = isLate;
  return declaration;
}

void main() {
  group('isFlattenableFunction', () {
    test(
      'a sync block of two or more expression statements is flattenable',
      () {
        expect(
          isFlattenableFunction(_function(Block([_expr(), _expr()]))),
          isTrue,
        );
      },
    );

    test('an async body is not flattenable', () {
      expect(
        isFlattenableFunction(
          _function(Block([_expr(), _expr()]), asyncMarker: AsyncMarker.Async),
        ),
        isFalse,
      );
    });

    test('fewer than two statements is not flattenable', () {
      expect(isFlattenableFunction(_function(Block([_expr()]))), isFalse);
    });

    test('a return statement does not disqualify the body', () {
      expect(
        isFlattenableFunction(_function(Block([_expr(), ReturnStatement()]))),
        isTrue,
      );
    });

    test('a variable declaration does not disqualify the body', () {
      expect(
        isFlattenableFunction(_function(Block([_local(), _expr()]))),
        isTrue,
      );
    });

    test('a late local declaration disqualifies the body', () {
      expect(
        isFlattenableFunction(
          _function(Block([_local(isLate: true), _expr()])),
        ),
        isFalse,
      );
    });

    test('a const local declaration disqualifies the body', () {
      expect(
        isFlattenableFunction(
          _function(Block([_local(isConst: true), _expr()])),
        ),
        isFalse,
      );
    });

    test('an unsupported statement kind disqualifies the body', () {
      expect(
        isFlattenableFunction(
          _function(
            Block([_expr(), WhileStatement(BoolLiteral(false), Block([]))]),
          ),
        ),
        isFalse,
      );
    });

    test('a non-block body is not flattenable', () {
      expect(isFlattenableFunction(_function(ReturnStatement())), isFalse);
    });
  });
}
