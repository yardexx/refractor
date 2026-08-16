import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/string_encrypt/selection/string_encrypt_selector.dart';
import 'package:test/test.dart';

import '../../../../helpers/kernel_helpers.dart';

void main() {
  group('StringEncryptSelector', () {
    late Library coreLib;
    late Library convertLib;
    late Library userLib;
    late Component component;
    setUp(() {
      coreLib = makeDartCoreLibrary();
      convertLib = makeDartConvertLibrary();
      userLib = makeUserLibrary();
      component = makeComponent(
        coreLib: coreLib,
        userLib: userLib,
        extraLibraries: [convertLib],
      );
    });

    StringEncryptSelector makeSelector({
      List<RegExp> excludedLiteralPatterns = const [],
    }) {
      return StringEncryptSelector(
        scope: makeObfuscationScope(),
        excludedLiteralPatterns: excludedLiteralPatterns,
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
        excludedLiteralPatterns: [RegExp('KEEP_ME')],
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

    test('skips empty string literal segments in concatenations', () {
      final keptLiteral = StringLiteral('kept');
      final valueParam = VariableDeclaration('value');
      userLib.addProcedure(
        Procedure(
          Name('concat'),
          ProcedureKind.Method,
          FunctionNode(
            ReturnStatement(
              StringConcatenation([
                StringLiteral(''),
                VariableGet(valueParam),
                keptLiteral,
                StringLiteral(''),
              ]),
            ),
            positionalParameters: [valueParam],
            requiredParameterCount: 1,
          ),
          fileUri: userLib.fileUri,
        ),
      );

      final selection = makeSelector().select(component);

      expect(selection.selectedLiteralCount, 1);
      expect(selection.orderedLiterals, [same(keptLiteral)]);
    });
  });
}
