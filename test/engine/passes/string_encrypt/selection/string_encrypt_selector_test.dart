import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/string_encrypt/selection/string_encrypt_selector.dart';
import 'package:refractor/src/policy/string_encrypt_policy_view.dart';
import 'package:test/test.dart';

import '../../../../helpers/kernel_helpers.dart';

void main() {
  group('StringEncryptSelector', () {
    late Library coreLib;
    late Library userLib;
    late Component component;
    late Procedure decodeProcedure;

    setUp(() {
      coreLib = makeDartCoreLibrary();
      userLib = makeUserLibrary();
      decodeProcedure = Procedure(
        Name(r'_obfDecode$', userLib),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
        isStatic: true,
      );
      userLib.addProcedure(decodeProcedure);
      component = makeComponent(coreLib: coreLib, userLib: userLib);
    });

    StringEncryptSelector makeSelector({
      List<RegExp> excludePatterns = const [],
    }) {
      return StringEncryptSelector(
        projectScope: makeProjectScope(),
        policy: const StringEncryptPolicyView(),
        decodeProcedure: decodeProcedure,
        excludePatterns: excludePatterns,
      );
    }

    test('selects eligible string literals only', () {
      final selectedLiteral = StringLiteral('encrypt_me');
      final excludedLiteral = StringLiteral('KEEP_ME');
      userLib.addProcedure(
        Procedure(
          Name('demo'),
          ProcedureKind.Method,
          FunctionNode(
            Block([
              ExpressionStatement(selectedLiteral),
              ExpressionStatement(excludedLiteral),
              ReturnStatement(
                ConstantExpression(StringConstant('const_value')),
              ),
            ]),
          ),
          fileUri: userLib.fileUri,
        ),
      );

      final selection = makeSelector(
        excludePatterns: [RegExp('KEEP_ME')],
      ).select(component);

      expect(selection.contains(selectedLiteral), isTrue);
      expect(selection.contains(excludedLiteral), isFalse);
      expect(selection.selectedLiteralCount, 1);
      expect(selection.orderedLiterals, [same(selectedLiteral)]);
    });

    test('does not select annotation literals', () {
      final procedure = Procedure(
        Name('annotated'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      )..addAnnotation(StringLiteral('keep_annotation'));
      userLib.addProcedure(procedure);

      final selection = makeSelector().select(component);

      expect(selection.selectedLiteralCount, 0);
      expect(selection.orderedLiterals, isEmpty);
    });

    test('preserves traversal order explicitly', () {
      final firstLiteral = StringLiteral('first');
      final secondLiteral = StringLiteral('second');
      userLib.addProcedure(
        Procedure(
          Name('ordered'),
          ProcedureKind.Method,
          FunctionNode(
            Block([
              ExpressionStatement(firstLiteral),
              ExpressionStatement(secondLiteral),
            ]),
          ),
          fileUri: userLib.fileUri,
        ),
      );

      final selection = makeSelector().select(component);

      expect(
        selection.orderedLiterals,
        [same(firstLiteral), same(secondLiteral)],
      );
    });
  });
}
