import 'package:kernel/kernel.dart';
import 'package:refractor/src/utils/rename_helpers.dart';
import 'package:test/test.dart';

void main() {
  final fileUri = Uri.parse('test:test');

  group('memberNameText', () {
    test('returns name for Procedure', () {
      final cls = Class(name: 'C', fileUri: fileUri);
      final proc = Procedure(
        Name('doStuff'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: fileUri,
      );
      cls.addProcedure(proc);

      expect(memberNameText(proc), equals('doStuff'));
    });

    test('returns name for Field', () {
      final cls = Class(name: 'C', fileUri: fileUri);
      final field = Field.mutable(Name('myField'), fileUri: fileUri);
      cls.addField(field);

      expect(memberNameText(field), equals('myField'));
    });

    test('returns name for Constructor', () {
      final cls = Class(name: 'C', fileUri: fileUri);
      final ctor = Constructor(
        FunctionNode(EmptyStatement()),
        name: Name('named'),
        fileUri: fileUri,
      );
      cls.addConstructor(ctor);

      expect(memberNameText(ctor), equals('named'));
    });
  });

  group('hasEntryPointPragma', () {
    test(
      'returns true when annotations contain a pragma ConstantExpression',
      () {
        final coreUri = Uri.parse('dart:core');
        final pragmaClass = Class(name: 'pragma', fileUri: coreUri);
        Library(coreUri, fileUri: coreUri).addClass(pragmaClass);

        final annotation = ConstantExpression(
          InstanceConstant(pragmaClass.reference, [], {}),
        );

        expect(hasEntryPointPragma([annotation]), isTrue);
      },
    );

    test('returns false for empty annotation list', () {
      expect(hasEntryPointPragma([]), isFalse);
    });

    test('returns false for non-pragma annotations', () {
      final otherClass = Class(
        name: 'other',
        fileUri: Uri.parse('dart:core'),
      );
      final coreUri = Uri.parse('dart:core');
      Library(coreUri, fileUri: coreUri).addClass(otherClass);

      final annotation = ConstantExpression(
        InstanceConstant(otherClass.reference, [], {}),
      );

      expect(hasEntryPointPragma([annotation]), isFalse);
    });
  });
}
