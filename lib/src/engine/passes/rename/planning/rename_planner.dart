import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/naming.dart';
import 'package:refractor/src/engine/kernel_toolkit/relations/class_relations.dart';
import 'package:refractor/src/engine/kernel_toolkit/relations/member_model.dart';
import 'package:refractor/src/engine/pass/planning/pass_planner.dart';
import 'package:refractor/src/engine/passes/rename/planning/name_generator/name_generator.dart';
import 'package:refractor/src/engine/passes/rename/planning/name_generator/rename_name_request.dart';
import 'package:refractor/src/engine/passes/rename/planning/rename_plan.dart';
import 'package:refractor/src/engine/passes/rename/rename_safety_normalizer.dart';
import 'package:refractor/src/engine/passes/rename/reporting/rename_mapping.dart';
import 'package:refractor/src/engine/passes/rename/reporting/symbol_map_key.dart';
import 'package:refractor/src/engine/passes/rename/selection/rename_selection.dart';
import 'package:refractor/src/utils/disjoint_set.dart';

final class RenamePlanner implements PassPlanner<RenameSelection, RenamePlan> {
  RenamePlanner({
    required this.generator,
    RenameSafetyNormalizer? safetyNormalizer,
  }) : _safetyNormalizer = safetyNormalizer ?? const RenameSafetyNormalizer();

  final NameGenerator generator;
  final RenameSafetyNormalizer _safetyNormalizer;

  @override
  Future<RenamePlan> plan(
    Component component,
    RenameSelection selection,
  ) async {
    final memberFamilies = _buildMemberFamilies(
      selection.instanceMembersByClass,
    );
    final requests = _buildRequests(selection, memberFamilies);
    final generatedNames = await generator.generateNames(requests);
    final mapping = _safetyNormalizer.normalize(
      component,
      _materialize(generatedNames),
    );

    return RenamePlan(
      mapping: mapping,
      plannedClasses: _countPlannedClassRenames(mapping),
      plannedMembers: _countPlannedMemberRenames(mapping),
      plannedVariables: _countPlannedVariableRenames(mapping),
    );
  }

  List<RenameNameRequest> _buildRequests(
    RenameSelection selection,
    List<_MemberFamily> memberFamilies,
  ) {
    return [
      for (final family in memberFamilies)
        FamilyRenameNameRequest(
          members: family.members,
          originalName: family.originalName,
          privacyScope: family.privacyScope,
        ),
      for (final member in selection.singletonMembers)
        MemberRenameNameRequest(
          member: member,
          originalName: MemberModel.nameText(member),
          privacyScope: MemberModel.nameText(member).startsWith('_')
              ? member.enclosingLibrary
              : null,
        ),
      for (final cls in selection.classes)
        ClassRenameNameRequest(
          cls: cls,
          originalName: cls.name,
        ),
      for (final variable in selection.variables)
        if (variable.name != null && variable.name!.isNotEmpty)
          VariableRenameNameRequest(
            variable: variable,
            originalName: variable.name!,
          ),
    ];
  }

  RenameMapping _materialize(Map<RenameNameRequest, String> assignedNames) {
    final members = <Member, Name>{};
    final classes = <Class, String>{};
    final variables = <VariableDeclaration, String>{};
    final symbolMap = <String, String>{};
    final privateLegacyKeys = <String, Set<String>>{};

    for (final entry in assignedNames.entries) {
      final request = entry.key;
      final rawName = entry.value;

      switch (request) {
        case FamilyRenameNameRequest():
          final name = request.privacyScope == null
              ? Name(rawName)
              : Name('_$rawName', request.privacyScope);
          for (final member in request.members) {
            members[member] = name;
          }
          if (request.originalName.isNotEmpty) {
            symbolMap[SymbolMapKey.forName(name)] = request.originalName;
            if (name.library != null) {
              (privateLegacyKeys[name.text] ??= <String>{}).add(
                request.originalName,
              );
            }
          }
        case MemberRenameNameRequest():
          final name = request.privacyScope == null
              ? Name(rawName)
              : Name('_$rawName', request.privacyScope);
          members[request.member] = name;
          if (request.originalName.isNotEmpty) {
            symbolMap[SymbolMapKey.forName(name)] = request.originalName;
            if (name.library != null) {
              (privateLegacyKeys[name.text] ??= <String>{}).add(
                request.originalName,
              );
            }
          }
        case ClassRenameNameRequest():
          classes[request.cls] = rawName;
          if (request.originalName.isNotEmpty) {
            symbolMap[rawName] = request.originalName;
          }
        case VariableRenameNameRequest():
          variables[request.variable] = rawName;
          if (request.originalName.isNotEmpty) {
            symbolMap[rawName] = request.originalName;
          }
      }
    }

    for (final entry in privateLegacyKeys.entries) {
      if (entry.value.length == 1) {
        symbolMap[entry.key] = entry.value.single;
      }
    }

    return RenameMapping(
      members: members,
      classes: classes,
      variables: variables,
      symbolMap: symbolMap,
    );
  }

  int _countPlannedClassRenames(RenameMapping mapping) {
    return mapping.classes.entries
        .where((entry) => entry.key.name != entry.value)
        .length;
  }

  int _countPlannedMemberRenames(RenameMapping mapping) {
    return mapping.members.entries
        .where((entry) => !KernelNames.same(entry.key.name, entry.value))
        .length;
  }

  int _countPlannedVariableRenames(RenameMapping mapping) {
    return mapping.variables.entries
        .where((entry) => entry.key.name != entry.value)
        .length;
  }

  List<_MemberFamily> _buildMemberFamilies(
    Map<Class, List<Member>> instanceMembersByClass,
  ) {
    final classes = instanceMembersByClass.keys.toList();
    final hierarchy = ClassRelationIndex.build(classes);
    final grouped = <(String, Uri?), List<(Member, Class)>>{};

    for (final cls in classes) {
      for (final member in instanceMembersByClass[cls] ?? const <Member>[]) {
        final name = MemberModel.nameText(member);
        if (name.isEmpty) continue;
        final privacyScope = name.startsWith('_')
            ? member.enclosingLibrary.importUri
            : null;
        (grouped[(name, privacyScope)] ??= <(Member, Class)>[]).add(
          (member, cls),
        );
      }
    }

    final unionFind = DisjointSet<Member>();
    for (final entry in grouped.entries) {
      final memberName = entry.key.$1;
      final members = entry.value;
      for (var i = 0; i < members.length; i++) {
        final (memberA, classA) = members[i];
        for (var j = i + 1; j < members.length; j++) {
          final (memberB, classB) = members[j];
          if (hierarchy.areRelated(classA, classB) ||
              hierarchy.shareDeclaringSupertypeForName(
                classA,
                classB,
                memberName,
              )) {
            unionFind.union(memberA, memberB);
          }
        }
      }
    }

    final rootToMembers = <Member, Set<Member>>{};
    for (final members in grouped.values) {
      for (final (member, _) in members) {
        final root = unionFind.find(member);
        (rootToMembers[root] ??= <Member>{}).add(member);
      }
    }

    return [
      for (final entry in rootToMembers.entries)
        _MemberFamily(
          members: entry.value,
          originalName: MemberModel.nameText(entry.key),
          privacyScope: MemberModel.nameText(entry.key).startsWith('_')
              ? entry.key.enclosingLibrary
              : null,
        ),
    ];
  }
}

final class _MemberFamily {
  const _MemberFamily({
    required this.members,
    required this.originalName,
    this.privacyScope,
  });

  final Set<Member> members;
  final String originalName;
  final Library? privacyScope;
}
