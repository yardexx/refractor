import 'dart:io';

import 'package:mason_logger/mason_logger.dart' show ExitCode;
import 'package:refractor/src/cli/commands/refractor_command.dart';
import 'package:refractor/src/cli/symbol_table_io.dart';
import 'package:refractor/src/config/config_manager.dart';
import 'package:refractor/src/engine/compiler/dart_compiler.dart';
import 'package:refractor/src/engine/engine.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';

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
    final ws = workspace..ensureBuildDirectory();

    final request = BuildRequest(
      input: input,
      output: output,
      target: target,
      workDirectory: ws.buildDirectory.path,
      projectRootUri: ws.rootUri,
      projectPackageName: ws.packageName,
    );

    final engine = RefractorEngine(
      compiler: DartCompiler(),
      kernelIO: FileKernelIO(),
    );

    try {
      final result = await engine.run(request: request, config: config);
      if (result.failures.isNotEmpty) {
        logger.err('Build failed: one or more passes reported failure.');
        // TODO(jaroslav): Process and print pass reports via a dedicated
        //  reporting feature instead of inline command logic.
        return ExitCode.software.code;
      }

      logger.detail('Writing output to ${result.outputPath}...');
      // TODO(jaroslav): Route symbol maps and other auxiliary outputs through
      //  dedicated artifact-handling boundary once that feature lands.
      result.symbolTable.writeToPath(config.symbolMapPath);
      logger.success('Build complete: ${result.outputPath}');
      // TODO(jaroslav): Process and print pass reports via a dedicated
      //  reporting feature instead of inline command logic.
      return ExitCode.success.code;
    } on Exception catch (e) {
      throw BuildException('Build failed: $e', cause: e);
    }
  }
}
