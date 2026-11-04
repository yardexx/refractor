import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/selection/bogus_control_flow_selection.dart';
import 'package:test/test.dart';

void main() {
  final intType = InterfaceType(
    Class(name: 'int', fileUri: Uri.parse('dart:core')),
    Nullability.nonNullable,
  );
  final nullableIntType = InterfaceType(
    Class(name: 'int', fileUri: Uri.parse('dart:core')),
    Nullability.nullable,
  );

  VariableDeclaration intParam() => VariableDeclaration('p', type: intType);
  VariableDeclaration dynParam() => VariableDeclaration('x');

  ExpressionStatement stmt() => ExpressionStatement(StringLiteral('x'));

  FunctionNode function({
    List<VariableDeclaration> positional = const [],
    List<VariableDeclaration> named = const [],
    Statement? body,
    AsyncMarker asyncMarker = AsyncMarker.Sync,
  }) {
    return FunctionNode(
      body ?? Block([stmt()]),
      positionalParameters: positional,
      namedParameters: named,
      asyncMarker: asyncMarker,
    );
  }

  group('isBogusControlFlowTarget / bogusGuardCandidates', () {
    test('a sync block body with an int parameter is a target', () {
      final node = function(positional: [intParam()]);
      expect(isBogusControlFlowTarget(node, maxStatements: 16), isTrue);
      expect(bogusGuardCandidates(node), hasLength(1));
    });

    test('a named int parameter also qualifies', () {
      final node = function(named: [intParam()]);
      expect(isBogusControlFlowTarget(node, maxStatements: 16), isTrue);
      expect(bogusGuardCandidates(node), hasLength(1));
    });

    test('no int parameter is not a target', () {
      final node = function(positional: [dynParam()]);
      expect(bogusGuardCandidates(node), isEmpty);
      expect(isBogusControlFlowTarget(node, maxStatements: 16), isFalse);
    });

    test('a nullable int parameter does not qualify', () {
      final node = function(
        positional: [VariableDeclaration('p', type: nullableIntType)],
      );
      expect(isBogusControlFlowTarget(node, maxStatements: 16), isFalse);
    });

    test('an async body is not a target', () {
      final node = function(
        positional: [intParam()],
        asyncMarker: AsyncMarker.Async,
      );
      expect(isBogusControlFlowTarget(node, maxStatements: 16), isFalse);
    });

    test('an empty block body is not a target', () {
      final node = function(positional: [intParam()], body: Block([]));
      expect(isBogusControlFlowTarget(node, maxStatements: 16), isFalse);
    });

    test('a body exceeding maxStatements is not a target', () {
      final node = function(
        positional: [intParam()],
        body: Block([stmt(), stmt(), stmt()]),
      );
      expect(isBogusControlFlowTarget(node, maxStatements: 2), isFalse);
      expect(isBogusControlFlowTarget(node, maxStatements: 3), isTrue);
    });

    test('a non-block body is not a target', () {
      final node = function(positional: [intParam()], body: ReturnStatement());
      expect(isBogusControlFlowTarget(node, maxStatements: 16), isFalse);
    });
  });
}
