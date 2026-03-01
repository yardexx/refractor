import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:test/test.dart';

void main() {
  group('Target.fromString', () {
    test('parses known targets', () {
      expect(Target.fromString('exe'), Target.exe);
      expect(Target.fromString('aot'), Target.aot);
      expect(Target.fromString('jit'), Target.jit);
      expect(Target.fromString('kernel'), Target.kernel);
    });

    test('throws BuildException for unknown target', () {
      expect(
        () => Target.fromString('web'),
        throwsA(isA<BuildException>()),
      );
    });
  });

  group('Target metadata', () {
    test('has expected dart compile values and extensions', () {
      expect(Target.exe.value, 'exe');
      expect(Target.exe.extension, '');

      expect(Target.aot.value, 'aot-snapshot');
      expect(Target.aot.extension, '.aot');

      expect(Target.jit.value, 'jit-snapshot');
      expect(Target.jit.extension, '.jit');

      expect(Target.kernel.value, 'kernel');
      expect(Target.kernel.extension, '.dill');
    });
  });
}
