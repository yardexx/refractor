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

  RenameMapping _normalizeDynamicDispatchNames(RenameMapping mapping) {
    final normalizedMembers = Map<Member, Name>.from(mapping.members);
    final dynamicGroups = <Name, List<Member>>{};

    for (final member in mapping.members.keys) {
      if (!_isDynamicDispatchMember(member)) continue;
      (dynamicGroups[member.name] ??= <Member>[]).add(member);
    }

    for (final group in dynamicGroups.values) {
      final distinctNames = {
        for (final member in group) normalizedMembers[member]!,
      };
      if (distinctNames.length <= 1) continue;

      group.sort(_compareMembers);
      final canonicalName = normalizedMembers[group.first]!;
      for (final member in group.skip(1)) {
        normalizedMembers[member] = canonicalName;
      }
    }

    final symbolMap = <String, String>{};
    for (final entry in normalizedMembers.entries) {
      if (entry.key.name.text.isNotEmpty) {
        symbolMap[symbolKeyForName(entry.value)] = entry.key.name.text;
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
