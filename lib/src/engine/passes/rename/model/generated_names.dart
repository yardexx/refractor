import 'package:kernel/kernel.dart';
import 'package:refractor/refractor.dart' show NameGenerator;
import 'package:refractor/src/engine/passes/rename/name_generator/name_generator.dart' show NameGenerator;
import 'package:refractor/src/engine/passes/rename/override_family/override_families.dart';

/// Raw name strings produced by a [NameGenerator].
///
/// Contains one name for every slot in the rename scope.
/// No privacy prefixes, no kernel [Name] objects — just bare strings
/// like `connect`, `foo`, `a`. The allocator adds `_` prefixes and
/// library scope.
class GeneratedNames {
  const GeneratedNames({
    required this.familyNames,
    required this.singletonNames,
    required this.classNames,
    required this.variableNames,
  });

  /// One name for each override family.
  final Map<OverrideFamily, String> familyNames;

  /// One name for each singleton member (top-level, static).
  final Map<Member, String> singletonNames;

  /// One name for each class.
  final Map<Class, String> classNames;

  /// One name for each variable.
  final Map<VariableDeclaration, String> variableNames;
}
