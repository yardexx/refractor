import 'dart:convert';
import 'dart:io';

/// Tracks the mapping from original identifiers to their obfuscated names.
/// Useful for generating a symbol map that can be used to deobfuscate stack
/// traces.
///
/// This class is pure (no dart:io). For file writing, see the
/// `symbol_table_io.dart` extension in the IO layer.
class SymbolTable {
  // obfuscated -> original
  final Map<String, String> _map = {};

  /// Record a rename: [original] was renamed to [obfuscated].
  void record(String original, String obfuscated) {
    _map[obfuscated] = original;
  }

  /// Look up the original name for an [obfuscated] name.
  String? original(String obfuscated) => _map[obfuscated];

  /// Look up the obfuscated name for an [original] name (reverse lookup).
  String? obfuscated(String original) {
    for (final entry in _map.entries) {
      if (entry.value == original) return entry.key;
    }
    return null;
  }

  void writeToFile(String path) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(toJsonString());
  }

  /// Export as a JSON-encodable map (obfuscated -> original).
  Map<String, String> toJson() => Map.unmodifiable(_map);

  /// Export as a pretty-printed JSON string.
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(_map);

  int get size => _map.length;
}
