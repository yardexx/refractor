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

  group('hasRefractorKeepAnnotation', () {
    test(
      'returns true for RefractorKeep from refractor_annotation package',
      () {
        final annotationUri = Uri.parse(
          'package:refractor_annotation/refractor_annotation.dart',
        );
        final annotationLib = Library(annotationUri, fileUri: annotationUri);
        final keepClass = Class(name: 'RefractorKeep', fileUri: annotationUri);
        annotationLib.addClass(keepClass);

        final annotation = ConstantExpression(
          InstanceConstant(keepClass.reference, const [], const {}),
        );

        expect(hasRefractorKeepAnnotation([annotation]), isTrue);
      },
    );

    test('returns false for empty annotation list', () {
      expect(hasRefractorKeepAnnotation([]), isFalse);
    });

    test('returns false for other package classes named RefractorKeep', () {
      final otherUri = Uri.parse('package:other/annotation.dart');
      final annotationLib = Library(otherUri, fileUri: otherUri);
      final keepClass = Class(name: 'RefractorKeep', fileUri: otherUri);
      annotationLib.addClass(keepClass);

      final annotation = ConstantExpression(
        InstanceConstant(keepClass.reference, const [], const {}),
      );

      expect(hasRefractorKeepAnnotation([annotation]), isFalse);
    });
  });
}
