import 'package:mason_logger/mason_logger.dart';
import 'package:refractor/src/cli/project_workspace.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/engine/kernel/kernel_io.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass/pass_registry.dart';
import 'package:refractor/src/engine/pass_runner.dart';
import 'package:refractor/src/project/project_scope.dart';

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

  BuildRequest.withWorkspace({
    required this.input,
    required this.target,
    required ProjectWorkspace workspace,
  }) : output = workspace.primaryOutputPath(target.extension),
       workDirectory = workspace.buildDirectory.path,
       projectRootUri = workspace.root.uri,
       projectPackageName = workspace.packageName;

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
    PassRegistry passRegistry = defaultPassRegistry,
    Logger? logger,
  }) : _passRegistry = passRegistry,
       _logger = logger;
  final Compiler compiler;
  final KernelIO kernelIO;
  final PassRegistry _passRegistry;
  final Logger? _logger;

  Future<BuildResult> run({
    required RefractorConfig config,
    required BuildRequest request,
  }) async {
    _logger?.detail('Compiling ${request.input} to kernel...');
    final dillPath = '${request.workDirectory}/app.dill';
    compiler.compileToKernel(request.input, dillPath);

    _logger?.detail('Running obfuscation passes...');
    final component = kernelIO.load(dillPath);
    final projectScope = ProjectScope(
      projectRootUri: request.projectRootUri,
      projectPackageName: request.projectPackageName,
    );

    final enabledPasses = _passRegistry.createAll(
      configs: config.passes,
      component: component,
      globalExcludes: config.excludePatterns,
      projectScope: projectScope,
    );

    final runner = PassRunner(passes: enabledPasses, logger: _logger);
    final runResult = await runner.run(component);

    if (runResult.failures.isNotEmpty) {
      _logger?.detail(
        'Skipping output generation because one or more passes failed.',
      );

      return BuildResult(
        outputPath: request.output,
        passesRun: enabledPasses.map((p) => p.name).toList(),
        passResults: runResult,
        reports: runResult.reports,
        failures: runResult.failures,
        skipped: runResult.skipped,
      );
    }

    _logger?.detail('Writing obfuscated kernel...');
    final obfuscatedDillPath = '${request.workDirectory}/app.obfuscated.dill';
    kernelIO.write(component, obfuscatedDillPath);

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
      passesRun: enabledPasses.map((p) => p.name).toList(),
      passResults: runResult,
      reports: runResult.reports,
      failures: runResult.failures,
      skipped: runResult.skipped,
    );
  }
}

/// Result of an [RefractorEngine.run] invocation.
class BuildResult {
  BuildResult({
    required this.outputPath,
    required this.passesRun,
    required this.passResults,
    this.reports = const [],
    this.failures = const [],
    this.skipped = const [],
  });

  final String outputPath;
  final List<String> passesRun;
  final PassResults passResults;
  final List<PassReport> reports;
  final List<PassFailureRecord> failures;

  /// Passes not run because an earlier pass failed (fail-fast).
  final List<String> skipped;
}
