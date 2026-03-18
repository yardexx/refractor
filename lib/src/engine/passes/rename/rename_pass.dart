import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/materialization/name_materializer.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_mapping.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_pass_options.dart';
import 'package:refractor/src/engine/passes/rename/name_generator/name_generator.dart';
import 'package:refractor/src/engine/passes/rename/name_generator/sequential_generator.dart';
import 'package:refractor/src/engine/passes/rename/name_generator/shuffled_generator.dart';
import 'package:refractor/src/engine/passes/rename/planning/rename_planner.dart';
import 'package:refractor/src/engine/passes/rename/planning/rename_slot_builder.dart';
import 'package:refractor/src/engine/passes/rename/rename_transformer.dart';
import 'package:refractor/src/engine/policy/obfuscation_policy_resolver.dart';
import 'package:refractor/src/engine/runner/obfuscation_target.dart';
import 'package:refractor/src/engine/runner/pass.dart';
import 'package:refractor/src/utils/rename_helpers.dart';
import 'package:refractor/src/utils/result.dart';

/// Obfuscation pass that renames user-defined identifiers.
///
/// Safety note: named parameters on non-static instance methods are preserved.
/// Kernel dynamic invocations do not have enough target information to rewrite
/// those labels soundly once the receiver type becomes `dynamic`.
///
/// Dumb orchestrator wiring three phases:
///   1. Collect — gather all declarations to rename.
///   2. Generate + Allocate — produce an obfuscation map.
///   3. Apply — mutate the AST and unbind canonical names.
class RenamePass extends Pass<RenameMapping> {
  RenamePass({
    this.options = const RenamePassOptions(),
    NameGenerator? generator,
  }) : _generator = generator;

  final RenamePassOptions options;
  final NameGenerator? _generator;

  @override
  String get name => 'rename';

  @override
  Future<Result<RenameMapping>> run(
    Component component,
    ObfuscationTarget target,
  ) async {
    try {
      final policy = ObfuscationPolicyResolver().resolve(
        component,
        target,
        renameOptions: options,
      );
      final plan = RenamePlanner(policy: policy).plan(component);
      final slots = RenameSlotBuilder().build(plan);

      final generator = _generator ?? _defaultGenerator();
      final names = await generator.generateNames(slots);

      final mapping = _normalizeDynamicDispatchNames(
        component,
        NameMaterializer().materialize(names),
      );

      RenameTransformer(mapping: mapping, target: target).apply(component);

      return Result.ok(mapping);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  NameGenerator _defaultGenerator() {
    return switch (options.namingStrategy) {
      NamingStrategy.shuffled => ShuffledGenerator(seed: options.seed),
      NamingStrategy.sequential => SequentialGenerator(),
    };
  }

  RenameMapping _normalizeDynamicDispatchNames(
    Component component,
    RenameMapping mapping,
  ) {
    final normalizedMembers = Map<Member, Name>.from(mapping.members);
    final dynamicGroups = <Name, List<Member>>{};

    for (final library in component.libraries) {
      for (final cls in library.classes) {
        for (final member in [...cls.procedures, ...cls.fields]) {
          if (!_isDynamicDispatchMember(member)) continue;
          (dynamicGroups[member.name] ??= <Member>[]).add(member);
        }
      }
    }

    final privateLegacyKeys = <String, Set<String>>{};

    for (final group in dynamicGroups.values) {
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
          !_sameName(entry.key.name, entry.value)) {
        symbolMap[symbolKeyForName(entry.value)] = entry.key.name.text;
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
      final originalName = entry.key.name;
      if (originalName != null && originalName.isNotEmpty) {
        symbolMap[entry.value] = originalName;
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
      variables: mapping.variables,
      symbolMap: symbolMap,
    );
  }

  bool _isDynamicDispatchMember(Member member) {
    return switch (member) {
      Procedure(isStatic: false) => true,
      Field(isStatic: false) => true,
      _ => false,
    };
  }

  bool _sameName(Name a, Name b) {
    return a.text == b.text && identical(a.library, b.library);
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
