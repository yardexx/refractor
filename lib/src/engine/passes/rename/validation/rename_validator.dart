import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/pass/validation/pass_validator.dart';
import 'package:refractor/src/engine/passes/rename/planning/rename_plan.dart';
import 'package:refractor/src/engine/passes/rename/reporting/rename_mapping.dart';
import 'package:refractor/src/engine/passes/rename/transformation/rename_transform_output.dart';
import 'package:refractor/src/utils/rename_helpers.dart';

final class RenameValidator
    implements PassValidator<RenamePlan, RenameTransformOutput> {
  const RenameValidator();

  @override
  void validate(
    Component component, {
    required RenamePlan plan,
    required RenameTransformOutput output,
  }) {
    final mapping = plan.mapping;
    if (output.renamedClasses != plan.plannedClasses) {
      throw StateError(
        'Rename transform count mismatch for classes: '
        '${output.renamedClasses} != ${plan.plannedClasses}',
      );
    }
    if (output.renamedMembers != plan.plannedMembers) {
      throw StateError(
        'Rename transform count mismatch for members: '
        '${output.renamedMembers} != ${plan.plannedMembers}',
      );
    }
    if (output.renamedVariables != plan.plannedVariables) {
      throw StateError(
        'Rename transform count mismatch for variables: '
        '${output.renamedVariables} != ${plan.plannedVariables}',
      );
    }

    for (final entry in mapping.classes.entries) {
      if (entry.key.name != entry.value) {
        throw StateError(
          'Class ${entry.key} was not renamed to the planned name '
          '${entry.value}.',
        );
      }
    }

    for (final entry in mapping.members.entries) {
      if (!sameName(entry.key.name, entry.value)) {
        throw StateError(
          'Member ${entry.key} was not renamed to the planned name '
          '${entry.value}.',
        );
      }
    }

    for (final entry in mapping.variables.entries) {
      if (entry.key.name != entry.value) {
        throw StateError(
          'Variable ${entry.key} was not renamed to the planned name '
          '${entry.value}.',
        );
      }
    }

    _checkMemberCollisions(mapping);
    _checkClassCollisions(mapping);
  }

  /// Asserts that no two distinct renamed members in the same enclosing scope
  /// (class or library) were mapped to the same name.
  ///
  /// Members in one scope may legitimately share a name only as a single
  /// property surface — at most one field, one getter, and one setter (e.g. a
  /// field and its accessor, or a getter/setter pair). Anything else (two
  /// methods, two fields, or a method mixed with other members) means distinct
  /// symbols were conflated, which would corrupt dispatch. Members in different
  /// scopes (override families) are grouped separately and are expected to
  /// share a name.
  void _checkMemberCollisions(RenameMapping mapping) {
    final byScope = <TreeNode, Map<String, List<Member>>>{};
    for (final entry in mapping.members.entries) {
      final scope = _enclosingScope(entry.key);
      if (scope == null) continue;
      final key = symbolKeyForName(entry.value);
      ((byScope[scope] ??= {})[key] ??= <Member>[]).add(entry.key);
    }

    for (final scopeGroups in byScope.values) {
      for (final members in scopeGroups.values) {
        if (members.length <= 1 || _isSinglePropertySurface(members)) continue;
        final collidingNames = members
            .map((member) => member.name.text)
            .toSet()
            .join(', ');
        throw StateError(
          'Rename produced colliding member names in one scope: '
          '$collidingNames all map to "${members.first.name.text}".',
        );
      }
    }
  }

  /// Asserts that no two renamed classes in the same library were mapped to the
  /// same name.
  void _checkClassCollisions(RenameMapping mapping) {
    final byLibrary = <Library, Map<String, List<Class>>>{};
    for (final entry in mapping.classes.entries) {
      final library = _enclosingLibrary(entry.key);
      if (library == null) continue;
      ((byLibrary[library] ??= {})[entry.value] ??= <Class>[]).add(entry.key);
    }

    for (final libraryGroups in byLibrary.entries) {
      for (final classes in libraryGroups.value.values) {
        if (classes.length <= 1) continue;
        throw StateError(
          'Rename produced colliding class names in '
          '${libraryGroups.key.importUri}: '
          '${classes.length} classes map to "${classes.first.name}".',
        );
      }
    }
  }

  /// The nearest enclosing [Class] or [Library], or null for an unparented
  /// node.
  TreeNode? _enclosingScope(Member member) {
    var node = member.parent;
    while (node != null) {
      if (node is Class || node is Library) return node;
      node = node.parent;
    }
    return null;
  }

  Library? _enclosingLibrary(TreeNode node) {
    var current = node.parent;
    while (current != null) {
      if (current is Library) return current;
      current = current.parent;
    }
    return null;
  }

  /// Whether [members] form at most one property surface: a single field
  /// and/or a single getter and/or a single setter, with no methods or other
  /// member kinds. Such a group legitimately shares one name.
  bool _isSinglePropertySurface(List<Member> members) {
    var fields = 0;
    var getters = 0;
    var setters = 0;
    for (final member in members) {
      switch (member) {
        case Field():
          fields++;
        case Procedure(kind: ProcedureKind.Getter):
          getters++;
        case Procedure(kind: ProcedureKind.Setter):
          setters++;
        default:
          return false;
      }
    }
    return fields <= 1 && getters <= 1 && setters <= 1;
  }
}
