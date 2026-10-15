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

    test('a non-expression statement disqualifies the body', () {
      expect(
        isFlattenableFunction(_function(Block([_expr(), ReturnStatement()]))),
        isFalse,
      );
    });

    test('a non-block body is not flattenable', () {
      expect(isFlattenableFunction(_function(ReturnStatement())), isFalse);
    });
  });
}
