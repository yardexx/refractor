import 'package:mason_logger/mason_logger.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/engine/kernel/kernel_io.dart';
import 'package:refractor/src/engine/obfuscation_target.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass_runner.dart';
import 'package:refractor/src/engine/passes/rename/model.dart';
import 'package:refractor/src/engine/pipeline_builder.dart';
import 'package:refractor/src/engine/symbol_table.dart';

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

  Future<BuildResult> run({
    required RefractorConfig config,
    required BuildRequest request,
  }) async {
    // 1. Compile source → kernel.
    _logger?.detail('Compiling ${request.input} to kernel...');
    final dillPath = '${request.workDirectory}/app.dill';
    compiler.compileToKernel(request.input, dillPath);

    // 2. Load & obfuscate.
    _logger?.detail('Running obfuscation passes...');
    final enabledPasses = PipelineBuilder().build(config.passes);
    final component = kernelIO.load(dillPath);

    final obfuscationTarget = ObfuscationTarget(
      projectRootUri: request.projectRootUri,
      projectPackageName: request.projectPackageName,
      excludePatterns: config.excludePatterns,
    );

    final runner = PassRunner(passes: enabledPasses, logger: _logger);
    final runResult = await runner.run(component, obfuscationTarget);

    // Extract symbol table from rename pass results.
    final symbolTable = SymbolTable();
    final mapping = runResult.artifact<RenameArtifact>('rename')?.mapping;
    if (mapping != null) {
      // symbolMap is keyed obfuscated → original.
      for (final entry in mapping.symbolMap.entries) {
        symbolTable.record(entry.value, entry.key);
      }
    }

    if (runResult.failures.isNotEmpty) {
      _logger?.detail(
        'Skipping output generation because one or more passes failed.',
      );
      return BuildResult(
        outputPath: request.output,
        symbolTable: symbolTable,
        passesRun: enabledPasses.map((p) => p.name).toList(),
        reports: runResult.reports,
        failures: runResult.failures,
      );
    }

    // 3. Write obfuscated kernel.
    _logger?.detail('Writing obfuscated kernel...');
    final obfuscatedDillPath = '${request.workDirectory}/app.obfuscated.dill';
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

    return BuildResult(
      outputPath: request.output,
      symbolTable: symbolTable,
      passesRun: enabledPasses.map((p) => p.name).toList(),
      reports: runResult.reports,
      failures: runResult.failures,
    );
  }
}

/// Result of an [RefractorEngine.run] invocation.
class BuildResult {
  BuildResult({
    required this.outputPath,
    required this.symbolTable,
    required this.passesRun,
    this.reports = const [],
    this.failures = const [],
  });

  final String outputPath;
  final SymbolTable symbolTable;
  final List<String> passesRun;
  final List<PassReport> reports;
  final List<PassFailureRecord> failures;
}
