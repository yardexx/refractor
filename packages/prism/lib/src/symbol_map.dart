import 'dart:convert';
import 'dart:io';

/// A parsed Refractor symbol map.
///
/// The current on-disk format is a flat JSON object mapping each obfuscated
/// name to its original: `{ "_$0": "Application", ... }`. For verification we
/// care about the **originals** (the values): those are precisely the
/// identifiers from the user's code that renaming was supposed to erase, so
/// they are the set that must be absent from the shipped binary.
///
/// prism reads only this existing format — it does not depend on Refractor.
class SymbolMap {
  SymbolMap(this.entries);

  factory SymbolMap.parse(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map) {
      throw const FormatException(
        'Symbol map must be a JSON object of obfuscated->original names.',
      );
    }
    return SymbolMap({
      for (final entry in decoded.entries)
        entry.key.toString(): entry.value.toString(),
    });
  }

  factory SymbolMap.load(String path) =>
      SymbolMap.parse(File(path).readAsStringSync());

  /// obfuscated -> original
  final Map<String, String> entries;

  /// The original identifiers that must not survive as plaintext.
  ///
  /// Synthetic names (mixin applications, scoped `::` names, empty strings)
  /// are filtered out: they are not real source identifiers an attacker would
  /// read, and they would never appear verbatim in a native binary.
  Set<String> get originals => {
        for (final original in entries.values)
          if (_isCheckable(original)) original,
      };

  static final _identifier = RegExp(r'^_*[A-Za-z$][A-Za-z0-9_$]*$');

  static bool _isCheckable(String name) {
    if (name.isEmpty) return false;
    if (name.contains('&') || name.contains('::') || name.contains('#')) {
      return false;
    }
    return _identifier.hasMatch(name);
  }
}
