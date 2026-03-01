import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/dead_code/dead_code_pass.dart';
import 'package:test/test.dart';

import '../../helpers/kernel_helpers.dart';

void main() {
  group('DeadCodePass', () {
    late Library coreLib;
    late Library userLib;
    late Component component;

    setUp(() {
      coreLib = makeDartCoreLibrary();
      userLib = makeUserLibrary();
    });

    Procedure addProcWithStatements(List<Statement> statements) {
      final proc = Procedure(
        Name('fn'),
        ProcedureKind.Method,
        FunctionNode(Block(statements)),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);
      return proc;
    }

    test('single-statement block gets one dead branch prepended', () {
      final original = ReturnStatement(IntLiteral(42));
      final proc = addProcWithStatements([original]);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      final context = makePassContext();
      DeadCodePass().run(component, context);

      final body = proc.function.body! as Block;
      // 1 dead branch + 1 original = 2
      expect(body.statements, hasLength(2));
      expect(body.statements[0], isA<IfStatement>());
      expect(body.statements[1], same(original));
    });

    test('maxInsertions=2 inserts two branches before first two statements',
        () {
      final s1 = ExpressionStatement(IntLiteral(1));
      final s2 = ExpressionStatement(IntLiteral(2));
      final s3 = ExpressionStatement(IntLiteral(3));
      final proc = addProcWithStatements([s1, s2, s3]);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      final context = makePassContext();
      DeadCodePass(maxInsertionsPerProcedure: 2).run(component, context);

      final body = proc.function.body! as Block;
      // 2 dead branches + 3 original = 5
      expect(body.statements, hasLength(5));
      expect(body.statements[0], isA<IfStatement>());
      expect(body.statements[1], same(s1));
      expect(body.statements[2], isA<IfStatement>());
      expect(body.statements[3], same(s2));
      expect(body.statements[4], same(s3));
    });

    test('maxInsertions=0 inserts nothing', () {
      final original = ReturnStatement(IntLiteral(1));
      final proc = addProcWithStatements([original]);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      final context = makePassContext();
      DeadCodePass(maxInsertionsPerProcedure: 0).run(component, context);

      final body = proc.function.body! as Block;
      expect(body.statements, hasLength(1));
      expect(body.statements.first, same(original));
    });

    test('empty block body results in no insertion', () {
      final proc = addProcWithStatements([]);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      final context = makePassContext();
      DeadCodePass().run(component, context);

      final body = proc.function.body! as Block;
      expect(body.statements, isEmpty);
    });

    test('non-block (expression) body results in no insertion', () {
      final proc = Procedure(
        Name('arrow'),
        ProcedureKind.Method,
        FunctionNode(ReturnStatement(IntLiteral(1))),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      final context = makePassContext();
      DeadCodePass().run(component, context);

      // Body should still be a ReturnStatement, not a Block.
      expect(proc.function.body, isA<ReturnStatement>());
    });

    test('inserted node is IfStatement with BoolLiteral(false) condition', () {
      addProcWithStatements([ReturnStatement(IntLiteral(0))]);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      final context = makePassContext();
      DeadCodePass().run(component, context);

      final body =
          (userLib.procedures.first.function.body! as Block).statements;
      final ifStmt = body.first as IfStatement;
      expect(ifStmt.condition, isA<BoolLiteral>());
      expect((ifStmt.condition as BoolLiteral).value, isFalse);
    });

    test('dart: library procedures are not modified', () {
      final coreProc = Procedure(
        Name('coreHelper'),
        ProcedureKind.Method,
        FunctionNode(Block([ReturnStatement(IntLiteral(0))])),
        fileUri: coreLib.fileUri,
      );
      coreLib.addProcedure(coreProc);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      final context = makePassContext();
      DeadCodePass().run(component, context);

      final body = coreProc.function.body! as Block;
      expect(body.statements, hasLength(1));
      expect(body.statements.first, isA<ReturnStatement>());
    });
  });
}
