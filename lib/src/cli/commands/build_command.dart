import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:refractor/src/cli/commands/refractor_command.dart';
import 'package:refractor/src/config/config_manager.dart';
import 'package:refractor/src/engine/compiler/dart_compiler.dart';
import 'package:refractor/src/engine/engine.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:refractor/src/utils/result.dart';

/// Full compile -> obfuscate -> final-compile pipeline command.
///
/// Usage: `refractor build [options]`
///
/// Targets: exe, aot, jit, kernel (default: exe)
class BuildCommand extends RefractorCommand {
  BuildCommand({super.logger}) {
    argParser
      ..addOption(
        'input',
        abbr: 'i',
        help: 'Input Dart file or directory',
        defaultsTo: 'lib/main.dart',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output file path (defaults to build/out.<target-extension>)',
        defaultsTo: 'build',
      )
      ..addOption(
        'target',
        abbr: 't',
        help: 'Target format to build for (exe, aot, jit, kernel)',
        allowed: ['exe', 'aot', 'jit', 'kernel'],
        defaultsTo: 'exe',
      );
  }

  @override
  String get name => 'build';

  @override
  String get description => 'Compile, obfuscate, and build to a target format.';

  @override
  Future<int> run() async {
    final target = Target.fromString(argResults.option('target')!);
    final input = argResults.option('input')!;
    final outputDir = argResults.option('output')!;
    Directory(outputDir).createSync(recursive: true);
    final output = '$outputDir/out${target.extension}';

    final config = ConfigManager.loadConfig();

    final request = BuildRequest(
      input: input,
      output: output,
      target: target,
      workDirectory: workspace.path,
    );

    final engine = RefractorEngine(
      compiler: DartCompiler(),
      kernelIO: FileKernelIO(),
      logger: logger,
    );

    final result = engine.run(request: request, config: config);

    switch (result) {
      case Ok<BuildResult>():
        logger.detail('Writing output to ${result.value.outputPath}...');
        result.value.symbolTable.writeToFile(config.symbolMapPath);
      case Error<BuildResult>():
        throw BuildException('Build failed: ${result.error}');
    }

    logger.success('Build complete: ${result.value.outputPath}');
    return ExitCode.success.code;
  }
}
