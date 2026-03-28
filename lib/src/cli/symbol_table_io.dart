import 'dart:io';

import 'package:refractor/src/engine/symbol_table.dart';

extension SymbolTableIo on SymbolTable {
  void writeToPath(String path) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(toJsonString());
  }
}
