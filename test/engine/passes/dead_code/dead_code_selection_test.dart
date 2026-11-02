import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/dead_code/selection/dead_code_selection.dart';
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

  VariableDeclaration intLocal({
    bool isLate = false,
    bool isConst = false,
    bool initialized = true,
    DartType? type,
  }) {
    final declaration = VariableDeclaration(
      'v',
      type: type ?? intType,
      initializer: initialized ? IntLiteral(1) : null,
      isConst: isConst,
    )..isLate = isLate;
    return declaration;
  }

  FunctionNode function(
    List<VariableDeclaration> params, {
    Statement? body,
  }) {
    return FunctionNode(body ?? Block([]), positionalParameters: params);
  }

  group('deadCodeSites / isDeadCodeTarget', () {
    test('an int parameter yields a site at the start of the body', () {
      final node = function([intParam()]);
      final sites = deadCodeSites(node);
      expect(isDeadCodeTarget(node), isTrue);
      expect(sites, hasLength(1));
      expect(sites.single.insertionIndex, 0);
      expect(sites.single.variable, node.positionalParameters.single);
    });

    test('no int parameter and no int local is not a target', () {
      expect(deadCodeSites(function([dynParam()])), isEmpty);
      expect(isDeadCodeTarget(function([dynParam()])), isFalse);
      expect(isDeadCodeTarget(function([])), isFalse);
    });

    test('an int local yields a site just after its declaration', () {
      final local = intLocal();
      final node = function(
        [],
        body: Block([local, ExpressionStatement(StringLiteral('x'))]),
      );
      final sites = deadCodeSites(node);
      expect(sites, hasLength(1));
      expect(sites.single.insertionIndex, 1);
      expect(sites.single.variable, local);
    });

    test('a param and an int local yield two sites', () {
      final local = intLocal();
      final node = function([intParam()], body: Block([local]));
      expect(deadCodeSites(node).map((s) => s.insertionIndex), [0, 1]);
    });

    test('late, const, uninitialized, and nullable locals are excluded', () {
      for (final local in [
        intLocal(isLate: true),
        intLocal(isConst: true),
        intLocal(initialized: false),
        intLocal(type: nullableIntType),
      ]) {
        expect(deadCodeSites(function([], body: Block([local]))), isEmpty);
      }
    });

    test('a non-block body is not a target', () {
      expect(
        isDeadCodeTarget(function([intParam()], body: ReturnStatement())),
        isFalse,
      );
    });
  });

  group('sink eligibility', () {
    DeadCodeSite paramSite(FunctionNode node) =>
        DeadCodeSite(insertionIndex: 0, variable: node.positionalParameters[0]);

    test('reassign needs a later read of the guard variable', () {
      final param = intParam();
      final reads = function(
        [param],
        body: Block([ReturnStatement(VariableGet(param))]),
      );
      expect(canReassign(reads, paramSite(reads)), isTrue);

      final ignores = function([intParam()], body: Block([ReturnStatement()]));
      expect(canReassign(ignores, paramSite(ignores)), isFalse);
    });

    test('reassign is ruled out by a later write or a final variable', () {
      final param = intParam();
      final overwritten = function(
        [param],
        body: Block([
          ExpressionStatement(VariableSet(param, IntLiteral(2))),
          ReturnStatement(VariableGet(param)),
        ]),
      );
      expect(canReassign(overwritten, paramSite(overwritten)), isFalse);

      final local = intLocal()..isFinal = true;
      final finalLocal = function(
        [],
        body: Block([local, ReturnStatement(VariableGet(local))]),
      );
      expect(
        canReassign(
          finalLocal,
          DeadCodeSite(insertionIndex: 1, variable: local),
        ),
        isFalse,
      );
    });

    test('return needs a synchronous int-returning function', () {
      expect(
        canReturnInt(FunctionNode(Block([]), returnType: intType)),
        isTrue,
      );
      expect(
        canReturnInt(FunctionNode(Block([]), returnType: nullableIntType)),
        isFalse,
      );
      expect(
        canReturnInt(
          FunctionNode(
            Block([]),
            returnType: intType,
            asyncMarker: AsyncMarker.Async,
          ),
        ),
        isFalse,
      );
    });
  });
}
