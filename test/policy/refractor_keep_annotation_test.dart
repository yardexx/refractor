import 'package:kernel/kernel.dart';
import 'package:refractor/src/policy/refractor_keep_annotation.dart';
import 'package:test/test.dart';

void main() {
  ConstantExpression keepAnnotationFrom(String libraryUri) {
    final uri = Uri.parse(libraryUri);
    final library = Library(uri, fileUri: uri);
    final keepClass = Class(name: 'RefractorKeep', fileUri: uri);
    library.addClass(keepClass);
    return ConstantExpression(
      InstanceConstant(keepClass.reference, const [], const {}),
    );
  }

  group('RefractorKeepAnnotation.isPresentOn', () {
    test('true for RefractorKeep from the annotation package', () {
      expect(
        RefractorKeepAnnotation.isPresentOn([
          keepAnnotationFrom(
            'package:refractor_annotation/refractor_annotation.dart',
          ),
        ]),
        isTrue,
      );
    });

    test('true for RefractorKeep from the annotation src library', () {
      expect(
        RefractorKeepAnnotation.isPresentOn([
          keepAnnotationFrom('package:refractor_annotation/src/refractor.dart'),
        ]),
        isTrue,
      );
    });

    test('false for an empty annotation list', () {
      expect(RefractorKeepAnnotation.isPresentOn([]), isFalse);
    });

    test('false for a RefractorKeep from another package', () {
      expect(
        RefractorKeepAnnotation.isPresentOn([
          keepAnnotationFrom('package:other/annotation.dart'),
        ]),
        isFalse,
      );
    });
  });
}
