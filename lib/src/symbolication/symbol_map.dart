import 'dart:convert';

import 'package:refractor/src/exceptions/refractor_exception.dart';

/// The current schema version of the emitted symbol map. Bump when the on-disk
/// shape changes incompatibly.
const int currentSymbolMapVersion = 1;

/// Identifies the file as a refractor symbol map, so a consumer can reject an
/// unrelated JSON document.
const String symbolMapKind = 'refractor-symbol-map';

/// The stable, versioned deobfuscation contract: a mapping from obfuscated
/// identifiers (public members and classes by bare name; private members scoped
/// as `library-uri::name`) back to their original names.
///
/// This is the purpose-built input to `refractor symbolicate`, decoupled from
/// the human-facing build-artifacts report. It is produced from the rename
/// pass's mapping, which is already keyed obfuscated → original.
final class SymbolMap {
  const SymbolMap({
    required this.symbols,
    this.version = currentSymbolMapVersion,
  });

  /// Parses a symbol map, validating its [symbolMapKind] marker and that the
  /// symbol table is a string→string map. An unknown [version] is accepted so
  /// newer maps can still be read best-effort.
  factory SymbolMap.fromJson(Map<String, dynamic> json) {
    if (json['kind'] != symbolMapKind) {
      throw ConfigException(
        'Not a refractor symbol map (expected kind "$symbolMapKind", '
        'got "${json['kind']}").',
      );
    }
    final version = json['version'];
    if (version is! int) {
      throw const ConfigException('Symbol map "version" must be an integer.');
    }
    final rawSymbols = json['symbols'];
    if (rawSymbols is! Map) {
      throw const ConfigException('Symbol map "symbols" must be an object.');
    }
    return SymbolMap(
      version: version,
      symbols: <String, String>{
        for (final entry in rawSymbols.entries)
          entry.key.toString(): entry.value.toString(),
      },
    );
  }

  final int version;

  /// Obfuscated-or-scoped key → original name.
  final Map<String, String> symbols;

  /// The original name for [obfuscated], or null if it is not in the map.
  String? originalFor(String obfuscated) => symbols[obfuscated];

  Map<String, Object?> toJson() => {
    'version': version,
    'kind': symbolMapKind,
    'symbols': symbols,
  };

  /// Pretty-printed JSON, the on-disk form.
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}
