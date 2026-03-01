import 'package:kernel/kernel.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:refractor/src/engine/name_generator.dart';
import 'package:refractor/src/engine/runner/pass.dart';
import 'package:refractor/src/engine/runner/pass_context.dart';
import 'package:refractor/src/engine/runner/pass_options.dart';
import 'package:refractor/src/engine/symbol_table.dart';

export 'package:refractor/src/engine/runner/pass_context.dart';
export 'package:refractor/src/engine/runner/pass_options.dart';

/// Runs a list of [Pass]es over a kernel [Component].
class PassRunner {
  PassRunner({
    required this.passes,
    this.logger,
  });
  final List<Pass> passes;
  final Logger? logger;

  /// Run all passes on [component] and return it along with the symbol table.
  (Component, SymbolTable) run(Component component, PassOptions options) {
    final ctx = PassContext(
      symbolTable: SymbolTable(),
      nameGenerator: NameGenerator(),
      options: options,
    );

    for (final pass in passes) {
      logger?.detail('Running pass: ${pass.name}');
      pass.run(component, ctx);
      logger?.detail('Pass "${pass.name}" complete. ');
    }

    return (component, ctx.symbolTable);
  }
}
