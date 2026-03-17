import 'package:mason_logger/mason_logger.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/engine/kernel/kernel_io.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_mapping.dart';
import 'package:refractor/src/engine/runner/obfuscation_target.dart';
import 'package:refractor/src/engine/runner/pass_runner.dart';
import 'package:refractor/src/engine/symbol_table.dart';
import 'package:refractor/src/utils/result.dart';

export 'package:refractor/src/engine/compiler/compiler.dart' show Target;

/// Bundles the IO parameters for an [RefractorEngine.run] invocation.
class BuildRequest {
  const BuildRequest({
    required this.input,
    required this.output,
    required this.target,
    required this.workDirectory,
    required this.projectRootUri,
    required this.projectPackageName,
  });
  final String input;
  final String output;
  final Target target;
  final String workDirectory;
  final Uri projectRootUri;
  final String? projectPackageName;
}

/// Orchestrates the full compile → obfuscate → compile pipeline.
///
/// This is a pure engine-layer class. It depends on abstract [Compiler] and
/// [KernelIO] interfaces — the caller provides IO-layer implementations.
class RefractorEngine {
  RefractorEngine({
    required this.compiler,
    required this.kernelIO,
    Logger? logger,
  }) : _logger = logger;
  final Compiler compiler;
  final KernelIO kernelIO;
  final Logger? _logger;

  Future<Result<BuildResult>> run({
    required RefractorConfig config,
    required BuildRequest request,
  }) async {
    try {
      // 1. Compile source → kernel.
      _logger?.detail('Compiling ${request.input} to kernel...');
      final dillPath = '${request.workDirectory}/app.dill';
      compiler.compileToKernel(request.input, dillPath);

      // 2. Load & obfuscate.
      _logger?.detail('Running obfuscation passes...');
      final enabledPasses = config.buildPasses();
      final component = kernelIO.load(dillPath);

      final obfuscationTarget = ObfuscationTarget(
        projectRootUri: request.projectRootUri,
        projectPackageName: request.projectPackageName,
        excludePatterns: config.excludePatterns,
      );

      final runner = PassRunner(passes: enabledPasses, logger: _logger);
      final runResult = await runner.run(component, obfuscationTarget);

      switch (runResult) {
        case Ok(:final value):
          // Extract symbol table from rename pass results.
          final symbolTable = SymbolTable();
          final mapping = value.get<RenameMapping>('rename');
          if (mapping != null) {
            // symbolMap is keyed obfuscated → original.
            for (final entry in mapping.symbolMap.entries) {
              symbolTable.record(entry.value, entry.key);
            }
          }

          // 3. Write obfuscated kernel.
          _logger?.detail('Writing obfuscated kernel...');
          final obfuscatedDillPath =
              '${request.workDirectory}/app.obfuscated.dill';
          kernelIO.write(component, obfuscatedDillPath);

          // 4. Compile to target (or write directly for kernel target).
          switch (request.target) {
            case Target.exe:
            case Target.aot:
            case Target.jit:
              _logger?.detail('Compiling to target ${request.target}...');
              compiler.compileToTarget(
                obfuscatedDillPath,
                request.output,
                request.target,
              );
            case Target.kernel:
              _logger?.detail(
                'Writing obfuscated kernel to ${request.output}...',
              );
              kernelIO.write(component, request.output);
          }

          _logger?.detail('Build complete: ${request.output}');

          return Result.ok(
            BuildResult(
              outputPath: request.output,
              symbolTable: symbolTable,
              passesRun: enabledPasses.map((p) => p.name).toList(),
            ),
          );

        case Error(:final error):
          return Result.error(error);
      }
    } on Exception catch (e) {
      return Result.error(e);
    }
  }
}

/// Result of an [RefractorEngine.run] invocation.
class BuildResult {
  BuildResult({
    required this.outputPath,
    required this.symbolTable,
    required this.passesRun,
  });
  final String outputPath;
  final SymbolTable symbolTable;
  final List<String> passesRun;
}
