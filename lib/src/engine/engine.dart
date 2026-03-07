import 'package:mason_logger/mason_logger.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/engine/kernel/kernel_io.dart';
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

  Result<BuildResult> run({
    required RefractorConfig config,
    required BuildRequest request,
  }) => runCatching(() {
    // 1. Compile source → kernel.
    _logger?.detail('Compiling ${request.input} to kernel...');
    final dillPath = '${request.workDirectory}/app.dill';
    compiler.compileToKernel(request.input, dillPath);

    // 2. Load & obfuscate.
    _logger?.detail('Running obfuscation passes...');
    final enabledPasses = config.buildPasses();
    final component = kernelIO.load(dillPath);
    final runner = PassRunner(passes: enabledPasses);
    final (obfuscated, symbolTable) = runner.run(
      component,
      config.toOptions(),
      projectRootUri: request.projectRootUri,
      projectPackageName: request.projectPackageName,
    );

    // 3. Write obfuscated kernel.
    _logger?.detail('Writing obfuscated kernel...');
    final obfuscatedDillPath = '${request.workDirectory}/app.obfuscated.dill';
    kernelIO.write(obfuscated, obfuscatedDillPath);

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
        _logger?.detail('Writing obfuscated kernel to ${request.output}...');
        kernelIO.write(obfuscated, request.output);
    }

    _logger?.detail('Build complete: ${request.output}');

    return BuildResult(
      outputPath: request.output,
      symbolTable: symbolTable,
      passesRun: enabledPasses.map((p) => p.name).toList(),
    );
  });
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
