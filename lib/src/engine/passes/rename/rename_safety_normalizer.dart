import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/kernel_toolkit/naming.dart';
import 'package:refractor/src/engine/kernel_toolkit/relations/member_model.dart';
import 'package:refractor/src/engine/passes/rename/reporting/rename_mapping.dart';
import 'package:refractor/src/engine/passes/rename/reporting/symbol_map_key.dart';

/// Applies rename-specific safety normalization after name allocation.
///
/// This keeps the pass itself focused on orchestration while preserving
/// callable surfaces and dynamic dispatch selectors that cannot be rewritten
/// soundly from allocation data alone.
final class RenameSafetyNormalizer {
  const RenameSafetyNormalizer();

  /// [spelledSelectors] are names some code refers to by spelling where
  /// rename cannot rewrite it; every instance member with one of those names
  /// keeps it.
  RenameMapping normalize(
    Component component,
    RenameMapping mapping, {
    Set<Name> spelledSelectors = const {},
  }) {
    final normalizedMembers = Map<Member, Name>.from(mapping.members);
    for (final member in mapping.members.keys) {
      if (MemberModel.isInstanceDispatch(member) &&
          spelledSelectors.contains(member.name)) {
        normalizedMembers[member] = member.name;
      }
    }
    final normalizedVariables = Map<VariableDeclaration, String>.from(
      mapping.variables,
    );
    _preserveFirstClassCallableSurfaces(
      component,
      normalizedMembers,
      normalizedVariables,
    );
    final dynamicGroups = <Name, List<Member>>{};
    final usedDynamicSelectors = _collectUsedDynamicSelectors(component);

    for (final library in component.libraries) {
      for (final cls in library.classes) {
        for (final member in [...cls.procedures, ...cls.fields]) {
          if (!MemberModel.isInstanceDispatch(member)) continue;
          (dynamicGroups[member.name] ??= <Member>[]).add(member);
        }
      }
    }

    final privateLegacyKeys = <String, Set<String>>{};

    for (final entry in dynamicGroups.entries) {
      if (!usedDynamicSelectors.contains(entry.key)) continue;
      final group = entry.value;
      final renamed = [
        for (final member in group)
          if (normalizedMembers.containsKey(member)) member,
      ];
      if (renamed.isEmpty) continue;

      if (renamed.length != group.length) {
        for (final member in renamed) {
          normalizedMembers[member] = member.name;
        }
        continue;
      }

      final distinctNames = {
        for (final member in renamed) normalizedMembers[member]!,
      };
      if (distinctNames.length <= 1) continue;

      renamed.sort(_compareMembers);
      final canonicalName = normalizedMembers[renamed.first]!;
      for (final member in renamed.skip(1)) {
        normalizedMembers[member] = canonicalName;
      }
    }

    final symbolMap = <String, String>{};
    for (final entry in normalizedMembers.entries) {
      if (entry.key.name.text.isNotEmpty &&
          !KernelNames.same(entry.key.name, entry.value)) {
        symbolMap[SymbolMapKey.forName(entry.value)] = entry.key.name.text;
        if (entry.value.library != null) {
          (privateLegacyKeys[entry.value.text] ??= <String>{}).add(
            entry.key.name.text,
          );
        }
      }
    }
    for (final entry in mapping.classes.entries) {
      if (entry.key.name.isNotEmpty) {
        symbolMap[entry.value] = entry.key.name;
      }
    }
    for (final entry in mapping.variables.entries) {
      final obfuscatedName = normalizedVariables[entry.key];
      if (obfuscatedName == null) continue;
      final originalName = entry.key.name;
      if (originalName != null && originalName.isNotEmpty) {
        symbolMap[obfuscatedName] = originalName;
      }
    }
    for (final entry in privateLegacyKeys.entries) {
      if (entry.value.length == 1) {
        symbolMap[entry.key] = entry.value.single;
      }
    }

    return RenameMapping(
      members: normalizedMembers,
      classes: mapping.classes,
      variables: normalizedVariables,
      symbolMap: symbolMap,
    );
  }

  void _preserveFirstClassCallableSurfaces(
    Component component,
    Map<Member, Name> normalizedMembers,
    Map<VariableDeclaration, String> normalizedVariables,
  ) {
    final collector = _CallableSurfaceCollector();
    component.accept(collector);

    for (final member in collector.members) {
      final originalName = member.name;
      final renamedName = normalizedMembers[member];
      if (renamedName == null || KernelNames.same(originalName, renamedName)) {
        continue;
      }

      normalizedMembers[member] = originalName;
      _preserveParameterNames(
        member,
        normalizedVariables,
        includePositional: true,
      );
    }

    // A torn-off static procedure keeps its new name: the tear-off references
    // it, not its name. Only the named parameters stay, because a call through
    // the closure (or `Function.apply`) passes named arguments by label.
    for (final procedure in collector.staticProcedures) {
      _preserveParameterNames(
        procedure,
        normalizedVariables,
        includePositional: false,
      );
    }
  }

  void _preserveParameterNames(
    Member member,
    Map<VariableDeclaration, String> normalizedVariables, {
    required bool includePositional,
  }) {
    final function = switch (member) {
      Procedure() => member.function,
      Constructor() => member.function,
      _ => null,
    };
    if (function == null) return;

    for (final parameter in [
      if (includePositional) ...function.positionalParameters,
      ...function.namedParameters,
    ]) {
      final originalParameterName = parameter.name;
      if (originalParameterName == null || originalParameterName.isEmpty) {
        continue;
      }
      if (normalizedVariables.containsKey(parameter)) {
        normalizedVariables[parameter] = originalParameterName;
      }
    }
  }

  Set<Name> _collectUsedDynamicSelectors(Component component) {
    final collector = _DynamicSelectorCollector();
    component.accept(collector);
    return collector.names;
  }

  int _compareMembers(Member a, Member b) {
    final libraryCompare = a.enclosingLibrary.importUri.toString().compareTo(
      b.enclosingLibrary.importUri.toString(),
    );
    if (libraryCompare != 0) return libraryCompare;

    final classCompare = (a.enclosingClass?.name ?? '').compareTo(
      b.enclosingClass?.name ?? '',
    );
    if (classCompare != 0) return classCompare;

    final kindCompare = a.runtimeType.toString().compareTo(
      b.runtimeType.toString(),
    );
    if (kindCompare != 0) return kindCompare;

    return a.name.text.compareTo(b.name.text);
  }
}

class _DynamicSelectorCollector extends RecursiveVisitor {
  final Set<Name> names = <Name>{};

  @override
  void visitDynamicGet(DynamicGet node) {
    names.add(node.name);
    super.visitDynamicGet(node);
  }

  @override
  void visitDynamicSet(DynamicSet node) {
    names.add(node.name);
    super.visitDynamicSet(node);
  }

  @override
  void visitDynamicInvocation(DynamicInvocation node) {
    names.add(node.name);
    super.visitDynamicInvocation(node);
  }
}

/// Collects the members whose callable surface a tear-off exposes.
///
/// Torn-off static procedures go to [staticProcedures]: their name can change
/// safely, only their named parameters cannot. Every other torn-off member
/// goes to [members] and keeps its name and parameter names.
class _CallableSurfaceCollector extends RecursiveVisitor {
  final Set<Member> members = <Member>{};
  final Set<Procedure> staticProcedures = <Procedure>{};

  void _addStaticTarget(Member target) {
    if (target is Procedure && target.isStatic) {
      staticProcedures.add(target);
    } else {
      members.add(target);
    }
  }

  @override
  void visitStaticTearOff(StaticTearOff node) {
    _addStaticTarget(node.target);
    super.visitStaticTearOff(node);
  }

  @override
  void visitConstructorTearOff(ConstructorTearOff node) {
    members.add(node.target);
    super.visitConstructorTearOff(node);
  }

  @override
  void visitRedirectingFactoryTearOff(RedirectingFactoryTearOff node) {
    members.add(node.target);
    super.visitRedirectingFactoryTearOff(node);
  }

  @override
  void visitInstanceTearOff(InstanceTearOff node) {
    members.add(node.interfaceTarget);
    super.visitInstanceTearOff(node);
  }

  @override
  void visitConstantExpression(ConstantExpression node) {
    _visitConstant(node.constant);
    super.visitConstantExpression(node);
  }

  void _visitConstant(Constant constant) {
    switch (constant) {
      case StaticTearOffConstant():
        _addStaticTarget(constant.target);
      case ConstructorTearOffConstant():
        members.add(constant.target);
      case RedirectingFactoryTearOffConstant():
        members.add(constant.target);
      case InstantiationConstant():
        _visitConstant(constant.tearOffConstant);
      default:
        break;
    }
  }
}
