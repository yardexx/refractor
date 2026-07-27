import 'package:kernel/kernel.dart';

/// The full obfuscation map, ready to apply to the AST.
///
/// Output of the allocation phase — maps each declaration node to its
/// obfuscated name.
class RenameMapping {
  const RenameMapping({
    required this.members,
    required this.classes,
    required this.variables,
    this.symbolMap = const {},
  });

  /// All members (family + singleton) → obfuscated [Name].
  final Map<Member, Name> members;

  /// Class → obfuscated name string.
  final Map<Class, String> classes;

  /// Variable → obfuscated name string.
  final Map<VariableDeclaration, String> variables;

  /// Serializable form: obfuscated name -> original names.
  ///
  /// Most entries have a single original name. Overloaded instance-member
  /// families may legitimately map one obfuscated selector to multiple
  /// original selectors, so values are stored as lists and serialized as a
  /// string-or-list JSON shape for backwards compatibility.
  final Map<String, List<String>> symbolMap;

  Iterable<String> originalsFor(String obfuscatedName) =>
      symbolMap[obfuscatedName] ?? const <String>[];

  bool containsOriginalName(String originalName) {
    return symbolMap.values.any((names) => names.contains(originalName));
  }

  Map<String, Object> toJson() => Map.unmodifiable({
    for (final entry in symbolMap.entries)
      entry.key: entry.value.length == 1
          ? entry.value.single
          : List<String>.unmodifiable(entry.value),
  });
}
