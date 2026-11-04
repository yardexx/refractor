import 'dart:io';

import 'package:refractor/src/symbolication/symbol_map.dart';

/// Writes [map] to [path] as pretty JSON, creating parent directories. Mirrors
/// the artifacts-JSON writer so both outputs are produced the same way.
void writeSymbolMapToPath(SymbolMap map, String path) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(map.toJsonString());
}
