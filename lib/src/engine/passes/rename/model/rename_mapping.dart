import 'dart:convert';

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

  /// Serializable form: obfuscated name → original name.
  /// Keyed by obfuscated name (unique) to avoid silent overwrites when
  /// multiple original names share the same text in different scopes.
  /// Built during allocation so it's available even after the
  /// component is discarded.
  final Map<String, String> symbolMap;

  /// Export as a pretty-printed JSON string.
  String toJson() => const JsonEncoder.withIndent('  ').convert(symbolMap);
}
