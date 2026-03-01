import 'dart:io';

import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:test/test.dart';

void main() {
  group('FileKernelIO', () {
    test('load throws FileIoException when input file does not exist', () {
      final io = FileKernelIO();

      expect(
        () => io.load('missing.dill'),
        throwsA(isA<FileIoException>()),
      );
    });

    test('write creates parent directories and writes output', () async {
      final io = FileKernelIO();
      final tempDir = await Directory.systemTemp.createTemp('kernel_io_test_');
      final outputPath = '${tempDir.path}/nested/output.dill';
      final component = Component();

      io.write(component, outputPath);

      final outFile = File(outputPath);
      expect(outFile.existsSync(), isTrue);
      expect(outFile.lengthSync(), greaterThan(0));

      await tempDir.delete(recursive: true);
    });
  });
}
