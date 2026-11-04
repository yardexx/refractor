import 'dart:io';

import 'package:ci/ci.dart';
import 'package:mason_logger/mason_logger.dart' show ExitCode, Level;
import 'package:refractor/src/cli/commands/refractor_command.dart';
import 'package:refractor/src/cli/pass_results_io.dart';
import 'package:refractor/src/cli/reporting/build_reporter.dart';
import 'package:refractor/src/cli/reporting/github_reporter.dart';
import 'package:refractor/src/cli/reporting/text_reporter.dart';
import 'package:refractor/src/cli/symbol_map_io.dart';
import 'package:refractor/src/config/config_manager.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/compiler/dart_compiler.dart';
import 'package:refractor/src/engine/engine.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';
import 'package:refractor/src/engine/passes/rename/reporting/rename_artifact.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:refractor/src/symbolication/symbol_map.dart';

/// Full compile -> obfuscate -> final-compile pipeline command.
///
/// Usage: `refractor build [options]`
///
/// Targets: exe, aot, jit, kernel (default: exe)
class BuildCommand extends RefractorCommand {
  BuildCommand({
    super.logger,
    BuildReporter? reporter,
  }) : _reporter = reporter {
    argParser
      ..addOption(
        'input',
        abbr: 'i',
        help: 'Input Dart file or directory',
        defaultsTo: 'lib/main.dart',
      )
      ..addOption(
        'target',
        abbr: 't',
        help: 'Target format to build for (exe, aot, jit, kernel)',
        allowed: ['exe', 'aot', 'jit', 'kernel'],
        defaultsTo: 'exe',
      );
  }

  final BuildReporter? _reporter;

  @override
  String get name => 'build';

  @override
  String get description => 'Compile, obfuscate, and build to a target format.';

  BuildReporter get reporter => _reporter ?? _detectReporter();

  BuildResult runBuild({
    required BuildRequest request,
    required RefractorConfig config,
  }) {
    final engine = RefractorEngine(
      compiler: DartCompiler(logger: logger),
      kernelIO: FileKernelIO(),
      logger: logger,
    );

    return engine.run(request: request, config: config);
  }

  @override
  Future<int> run() async {
    final target = Target.fromString(argResults.option('target')!);
    final input = argResults.option('input')!;
    final config = ConfigManager.loadConfig();

    if (config.verbose) {
      logger.level = Level.verbose;
    }

    final request = workspace.toBuildRequest(
      input: input,
      target: target,
    );

    try {
      final result = runBuild(request: request, config: config);
      reporter.report(result);

      if (result.failures.isNotEmpty) {
        logger.err('Build failed: one or more passes reported failure.');
        return ExitCode.software.code;
      }

      logger.detail('Writing output to ${result.outputPath}...');
      final artifactPath = workspace.auxiliaryOutputPath(
        config.artifactJsonPath,
      );
      if (result.passResults.hasArtifacts) {
        result.passResults.writeArtifactsToPath(artifactPath);
      } else {
        final artifactFile = File(artifactPath);
        if (artifactFile.existsSync()) {
          artifactFile.deleteSync();
        }
      }

      _emitSymbolMap(result, config);

      logger.success('Build complete: ${result.outputPath}');
      return ExitCode.success.code;
    } on Exception catch (e) {
      throw BuildException('Build failed: $e', cause: e);
    }
  }

  /// Writes the stable, versioned symbol map from the rename mapping, or clears
  /// a stale file when this build renamed nothing. Kept separate from the
  /// bundled artifacts JSON so it stays a clean deobfuscation contract.
  void _emitSymbolMap(BuildResult result, RefractorConfig config) {
    final symbolMapPath = workspace.auxiliaryOutputPath(config.symbolMapPath);
    final rename = result.passResults.artifact<RenameArtifact>('rename');
    final symbols = rename?.mapping.symbolMap ?? const {};

    if (symbols.isEmpty) {
      final file = File(symbolMapPath);
      if (file.existsSync()) {
        file.deleteSync();
      }
      return;
    }

    writeSymbolMapToPath(SymbolMap(symbols: symbols), symbolMapPath);
    logger.detail('Wrote symbol map to $symbolMapPath');
  }

  BuildReporter _detectReporter() => isCI && Vendor.IS_GITHUB_ACTIONS
      ? GitHubReporter(logger)
      : TextReporter(logger);
}
