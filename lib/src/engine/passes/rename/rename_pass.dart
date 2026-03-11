import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_mapping.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_pass_options.dart';
import 'package:refractor/src/engine/passes/rename/name_allocator.dart';
import 'package:refractor/src/engine/passes/rename/name_generator/name_generator.dart';
import 'package:refractor/src/engine/passes/rename/name_generator/sequential_generator.dart';
import 'package:refractor/src/engine/passes/rename/name_generator/shuffled_generator.dart';
import 'package:refractor/src/engine/passes/rename/rename_collector.dart';
import 'package:refractor/src/engine/passes/rename/rename_transformer.dart';
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
      // 1. Collect.
      final scope = RenameCollector().collect(component, target, options);

      // 2. Generate names.
      final generator = _generator ?? _defaultGenerator();
      final names = await generator.generate(scope);

      // 3. Allocate (wire names into kernel Name objects).
      final mapping = NameAllocator().allocate(scope, names);

      // 4. Apply.
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
