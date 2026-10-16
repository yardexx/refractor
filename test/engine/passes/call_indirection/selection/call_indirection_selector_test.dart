import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/call_indirection/selection/call_indirection_selection.dart';
import 'package:test/test.dart';

void main() {
  final uri = Uri.parse('package:refractor/src/app.dart');

  Procedure procedure({
    List<TypeParameter> typeParameters = const [],
    ProcedureKind kind = ProcedureKind.Method,
    bool isStatic = true,
  }) {
    return Procedure(
      Name('f'),
      kind,
      FunctionNode(EmptyStatement(), typeParameters: typeParameters),
      isStatic: isStatic,
      fileUri: uri,
    );
  }

  StaticInvocation call(
    Procedure target, {
    List<Expression> positional = const [],
    List<NamedExpression> named = const [],
    List<DartType> types = const [],
  }) {
    return StaticInvocation(
      target,
      Arguments(positional, named: named, types: types),
    );
  }

  group('isIndirectableCall', () {
    test('a non-generic static-method call with positional args qualifies', () {
      expect(
        isIndirectableCall(call(procedure(), positional: [IntLiteral(1)])),
        isTrue,
      );
    });

    test('a generic target does not qualify', () {
      final target = procedure(typeParameters: [TypeParameter('T')]);
      expect(isIndirectableCall(call(target)), isFalse);
    });

    test('a call with named arguments does not qualify', () {
      expect(
        isIndirectableCall(
          call(
            procedure(),
            named: [NamedExpression('x', IntLiteral(1))],
          ),
        ),
        isFalse,
      );
    });

    test('a call with type arguments does not qualify', () {
      expect(
        isIndirectableCall(call(procedure(), types: [const DynamicType()])),
        isFalse,
      );
    });

    test('a non-method target (getter) does not qualify', () {
      expect(
        isIndirectableCall(call(procedure(kind: ProcedureKind.Getter))),
        isFalse,
      );
    });

    test('a non-static target does not qualify', () {
      expect(isIndirectableCall(call(procedure(isStatic: false))), isFalse);
    });
  });
}
