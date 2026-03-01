import 'dart:io';
import 'dart:typed_data';

import 'package:kernel/binary/ast_to_binary.dart';
import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/kernel/kernel_io.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';

/// File-based implementation of [KernelIO].
class FileKernelIO implements KernelIO {
  @override
  Component load(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileIoException('Input .dill file not found: $path');
    }
    return loadComponentFromBinary(path);
  }

  @override
  void write(Component component, String path) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    final sink = _BytesSink();
    BinaryPrinter(sink).writeComponentFile(component);
    file.writeAsBytesSync(sink.bytes);
  }
}

class _BytesSink implements Sink<List<int>> {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  @override
  void add(List<int> data) => _builder.add(data);

  @override
  void close() {}

  Uint8List get bytes => _builder.toBytes();
}
