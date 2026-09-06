import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/kernel_toolkit/naming.dart';
import 'package:test/test.dart';

void main() {
  group('KernelNames.same', () {
    test('public names are equal by text', () {
      expect(KernelNames.same(Name('a'), Name('a')), isTrue);
      expect(KernelNames.same(Name('a'), Name('b')), isFalse);
    });

    test('private names are equal only within the same library', () {
      final libA = Library(
        Uri.parse('package:app/a.dart'),
        fileUri: Uri.parse('package:app/a.dart'),
      );
      final libB = Library(
        Uri.parse('package:app/b.dart'),
        fileUri: Uri.parse('package:app/b.dart'),
      );

      expect(KernelNames.same(Name('_a', libA), Name('_a', libA)), isTrue);
      expect(KernelNames.same(Name('_a', libA), Name('_a', libB)), isFalse);
    });
  });
}
