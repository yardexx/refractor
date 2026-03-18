import 'dart:convert';

/// Tracks the mapping from original identifiers to their obfuscated names.
/// Useful for generating a symbol map that can be used to deobfuscate stack
/// traces.
///
/// This class is pure (no `dart:io`). For file writing, see the IO-layer
/// helpers in the CLI package.
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
    String? scopedMatch;
    for (final entry in _map.entries) {
      if (entry.value != original) continue;
      if (!entry.key.contains('::')) return entry.key;
      scopedMatch ??= entry.key;
    }
    return scopedMatch;
  }

  /// Export as a JSON-encodable map (obfuscated -> original).
  Map<String, String> toJson() => Map.unmodifiable(_map);

  /// Export as a pretty-printed JSON string.
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(_map);

  int get size => _map.length;
}
