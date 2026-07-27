import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/planning/pass_planner.dart';
import 'package:refractor/src/engine/passes/rename/planning/class_relation_index.dart';
import 'package:refractor/src/engine/passes/rename/planning/name_generator/name_generator.dart';
import 'package:refractor/src/engine/passes/rename/planning/name_generator/rename_name_request.dart';
import 'package:refractor/src/engine/passes/rename/planning/rename_plan.dart';
import 'package:refractor/src/engine/passes/rename/rename_safety_normalizer.dart';
import 'package:refractor/src/engine/passes/rename/reporting/rename_mapping.dart';
import 'package:refractor/src/engine/passes/rename/selection/rename_selection.dart';
import 'package:refractor/src/utils/disjoint_set.dart';
import 'package:refractor/src/utils/rename_helpers.dart';

final class RenamePlanner implements PassPlanner<RenameSelection, RenamePlan> {
  RenamePlanner({
    required this.generator,
    this.overloading = false,
    RenameSafetyNormalizer? safetyNormalizer,
  }) : _safetyNormalizer = safetyNormalizer ?? const RenameSafetyNormalizer();

  final NameGenerator generator;
  final bool overloading;
  final RenameSafetyNormalizer _safetyNormalizer;

  @override
  Future<RenamePlan> plan(
    Component component,
    RenameSelection selection,
  ) async {
    final hierarchy = ClassRelationIndex.build(
      selection.instanceMembersByClass.keys,
    );
    final memberFamilies = _buildMemberFamilies(
      selection.instanceMembersByClass,
      hierarchy,
    );
    final requests = _buildRequests(
      selection,
      memberFamilies,
      hierarchy,
    );
    final generatedNames = await generator.generateNames(requests.requests);
    final familyNames = <_MemberFamily, String>{
      for (final entry in requests.familyRequests.entries)
        entry.key: generatedNames[entry.value]!,
    };
    _validateNoDuplicateFamilyNames(familyNames);
    final mapping = _safetyNormalizer.normalize(
      component,
      _materialize(
        familyNames: familyNames,
        assignedNames: generatedNames,
      ),
    );

    return RenamePlan(
      mapping: mapping,
      plannedClasses: _countPlannedClassRenames(mapping),
      plannedMembers: _countPlannedMemberRenames(mapping),
      plannedVariables: _countPlannedVariableRenames(mapping),
    );
  }

  _PlannerRequests _buildRequests(
    RenameSelection selection,
    List<_MemberFamily> memberFamilies,
    ClassRelationIndex hierarchy,
  ) {
    final familyRequests = overloading
        ? _buildOverloadedFamilyRequests(memberFamilies, hierarchy)
        : {
            for (final family in memberFamilies)
              family: FamilyRenameNameRequest(
                members: family.members,
                originalName: family.originalName,
                privacyScope: family.privacyScope,
              ),
          };

    final uniqueFamilyRequests = <RenameNameRequest>{
      ...familyRequests.values,
    }.toList();

    return _PlannerRequests(
      requests: [
        ...uniqueFamilyRequests,
        for (final member in selection.singletonMembers)
          MemberRenameNameRequest(
            member: member,
            originalName: memberNameText(member),
            privacyScope: memberNameText(member).startsWith('_')
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
      ],
      familyRequests: familyRequests,
    );
  }

  Map<_MemberFamily, RenameNameRequest> _buildOverloadedFamilyRequests(
    List<_MemberFamily> memberFamilies,
    ClassRelationIndex hierarchy,
  ) {
    final familySlots = _assignFamilySlots(memberFamilies, hierarchy);
    final slotRequests = <(Uri?, int), RenameNameRequest>{};
    final familyRequests = <_MemberFamily, RenameNameRequest>{};

    for (final family in memberFamilies) {
      final slotKey = (_familyNamespace(family), familySlots[family]!);
      final request = slotRequests.putIfAbsent(
        slotKey,
        () => FamilyRenameNameRequest(
          members: family.members,
          originalName: family.originalName,
          privacyScope: family.privacyScope,
        ),
      );
      familyRequests[family] = request;
    }

    return familyRequests;
  }

  Map<_MemberFamily, int> _assignFamilySlots(
    List<_MemberFamily> memberFamilies,
    ClassRelationIndex hierarchy,
  ) {
    final familiesByNamespace = <Uri?, List<_MemberFamily>>{};
    for (final family in memberFamilies) {
      (familiesByNamespace[_familyNamespace(family)] ??= <_MemberFamily>[]).add(
        family,
      );
    }

    final assignments = <_MemberFamily, int>{};
    for (final entry in familiesByNamespace.entries) {
      final families = [...entry.value];
      final conflicts = <_MemberFamily, Set<_MemberFamily>>{
        for (final family in families) family: <_MemberFamily>{},
      };

      for (var i = 0; i < families.length; i++) {
        final familyA = families[i];
        for (var j = i + 1; j < families.length; j++) {
          final familyB = families[j];
          if (_familiesConflict(familyA, familyB, hierarchy)) {
            conflicts[familyA]!.add(familyB);
            conflicts[familyB]!.add(familyA);
          }
        }
      }

      families.sort((a, b) {
        final degreeCompare = conflicts[b]!.length.compareTo(
          conflicts[a]!.length,
        );
        if (degreeCompare != 0) return degreeCompare;
        return _compareFamilies(a, b);
      });

      for (final family in families) {
        final usedSlots = {
          for (final neighbor in conflicts[family]!)
            if (assignments.containsKey(neighbor)) assignments[neighbor]!,
        };
        var slot = 0;
        while (usedSlots.contains(slot)) {
          slot++;
        }
        assignments[family] = slot;
      }
    }

    return assignments;
  }

  bool _familiesConflict(
    _MemberFamily a,
    _MemberFamily b,
    ClassRelationIndex hierarchy,
  ) {
    if (a.declaringClasses.intersection(b.declaringClasses).isNotEmpty) {
      return true;
    }

    for (final classA in a.declaringClasses) {
      for (final classB in b.declaringClasses) {
        if (hierarchy.areRelated(classA, classB) ||
            hierarchy.shareScopedSubtype(classA, classB)) {
          return true;
        }
      }
    }

    return false;
  }

  RenameMapping _materialize({
    required Map<_MemberFamily, String> familyNames,
    required Map<RenameNameRequest, String> assignedNames,
  }) {
    final members = <Member, Name>{};
    final classes = <Class, String>{};
    final variables = <VariableDeclaration, String>{};
    final symbolMap = <String, Set<String>>{};
    final privateLegacyKeys = <String, Set<String>>{};

    for (final entry in familyNames.entries) {
      final family = entry.key;
      final rawName = entry.value;
      final name = family.privacyScope == null
          ? Name(rawName)
          : Name('_$rawName', family.privacyScope);
      for (final member in family.members) {
        members[member] = name;
      }
      if (family.originalName.isNotEmpty) {
        _recordSymbolName(
          symbolMap,
          symbolKeyForName(name),
          family.originalName,
        );
        if (name.library != null) {
          (privateLegacyKeys[name.text] ??= <String>{}).add(
            family.originalName,
          );
        }
      }
    }

    for (final entry in assignedNames.entries) {
      final request = entry.key;
      final rawName = entry.value;
      if (request is FamilyRenameNameRequest) {
        continue;
      }

      switch (request) {
        case FamilyRenameNameRequest():
          break;
        case MemberRenameNameRequest():
          final name = request.privacyScope == null
              ? Name(rawName)
              : Name('_$rawName', request.privacyScope);
          members[request.member] = name;
          if (request.originalName.isNotEmpty) {
            _recordSymbolName(
              symbolMap,
              symbolKeyForName(name),
              request.originalName,
            );
            if (name.library != null) {
              (privateLegacyKeys[name.text] ??= <String>{}).add(
                request.originalName,
              );
            }
          }
        case ClassRenameNameRequest():
          classes[request.cls] = rawName;
          if (request.originalName.isNotEmpty) {
            _recordSymbolName(symbolMap, rawName, request.originalName);
          }
        case VariableRenameNameRequest():
          variables[request.variable] = rawName;
          if (request.originalName.isNotEmpty) {
            _recordSymbolName(symbolMap, rawName, request.originalName);
          }
      }
    }

    for (final entry in privateLegacyKeys.entries) {
      if (entry.value.length == 1) {
        _recordSymbolName(symbolMap, entry.key, entry.value.single);
      }
    }

    return RenameMapping(
      members: members,
      classes: classes,
      variables: variables,
      symbolMap: _freezeSymbolMap(symbolMap),
    );
  }

  int _countPlannedClassRenames(RenameMapping mapping) {
    return mapping.classes.entries
        .where((entry) => entry.key.name != entry.value)
        .length;
  }

  int _countPlannedMemberRenames(RenameMapping mapping) {
    return mapping.members.entries
        .where((entry) => !_sameName(entry.key.name, entry.value))
        .length;
  }

  int _countPlannedVariableRenames(RenameMapping mapping) {
    return mapping.variables.entries
        .where((entry) => entry.key.name != entry.value)
        .length;
  }

  bool _sameName(Name a, Name b) {
    return a.text == b.text && identical(a.library, b.library);
  }

  List<_MemberFamily> _buildMemberFamilies(
    Map<Class, List<Member>> instanceMembersByClass,
    ClassRelationIndex hierarchy,
  ) {
    final grouped = <(String, Uri?), List<(Member, Class)>>{};

    for (final cls in instanceMembersByClass.keys) {
      for (final member in instanceMembersByClass[cls] ?? const <Member>[]) {
        final name = memberNameText(member);
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

    final families = [
      for (final entry in rootToMembers.entries)
        _MemberFamily(
          members: entry.value,
          originalName: memberNameText(entry.key),
          privacyScope: memberNameText(entry.key).startsWith('_')
              ? entry.key.enclosingLibrary
              : null,
          declaringClasses: {
            for (final member in entry.value)
              if (member.enclosingClass != null) member.enclosingClass!,
          },
        ),
    ]..sort(_compareFamilies);
    return families;
  }

  void _validateNoDuplicateFamilyNames(Map<_MemberFamily, String> familyNames) {
    final classNames = <Class, Map<(String, Uri?), _MemberFamily>>{};

    for (final entry in familyNames.entries) {
      final family = entry.key;
      final effectiveName = (
        family.privacyScope == null ? entry.value : '_${entry.value}',
        family.privacyScope?.importUri,
      );

      for (final declaringClass in family.declaringClasses) {
        final usedNames = classNames.putIfAbsent(
          declaringClass,
          () => <(String, Uri?), _MemberFamily>{},
        );
        final existing = usedNames[effectiveName];
        if (existing != null && !identical(existing, family)) {
          throw StateError(
            'Overloaded rename would assign duplicate member name '
            '"${effectiveName.$1}" in class ${declaringClass.name}.',
          );
        }
        usedNames[effectiveName] = family;
      }
    }
  }

  Uri? _familyNamespace(_MemberFamily family) => family.privacyScope?.importUri;

  void _recordSymbolName(
    Map<String, Set<String>> symbolMap,
    String obfuscatedName,
    String originalName,
  ) {
    (symbolMap[obfuscatedName] ??= <String>{}).add(originalName);
  }

  Map<String, List<String>> _freezeSymbolMap(
    Map<String, Set<String>> symbolMap,
  ) {
    return {
      for (final entry in symbolMap.entries)
        entry.key: List<String>.unmodifiable(entry.value.toList()..sort()),
    };
  }

  int _compareFamilies(_MemberFamily a, _MemberFamily b) {
    final nameCompare = a.originalName.compareTo(b.originalName);
    if (nameCompare != 0) return nameCompare;

    final privacyA = a.privacyScope?.importUri.toString() ?? '';
    final privacyB = b.privacyScope?.importUri.toString() ?? '';
    final privacyCompare = privacyA.compareTo(privacyB);
    if (privacyCompare != 0) return privacyCompare;

    return _familySignature(a).compareTo(_familySignature(b));
  }

  String _familySignature(_MemberFamily family) {
    final classNames =
        family.declaringClasses
            .map((cls) => '${cls.name}@${cls.fileUri}')
            .toList()
          ..sort();
    final memberNames =
        family.members
            .map((member) => '${memberNameText(member)}@${member.fileUri}')
            .toList()
          ..sort();
    return '${classNames.join(',')}|${memberNames.join(',')}';
  }
}

final class _MemberFamily {
  const _MemberFamily({
    required this.members,
    required this.originalName,
    required this.declaringClasses,
    this.privacyScope,
  });

  final Set<Member> members;
  final String originalName;
  final Set<Class> declaringClasses;
  final Library? privacyScope;
}

final class _PlannerRequests {
  const _PlannerRequests({
    required this.requests,
    required this.familyRequests,
  });

  final List<RenameNameRequest> requests;
  final Map<_MemberFamily, RenameNameRequest> familyRequests;
}
