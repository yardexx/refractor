import 'package:refractor_annotation/refractor_annotation.dart';
import 'package:test/test.dart';

void main() {
  test('refractor_annotation exports Refractor and RefractorKeep', () {
    const annotation = Refractor.keep();

    expect(annotation, isA<RefractorKeep>());
  });
}
