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

      final mapping = NameMaterializer().materialize(names);

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
}
