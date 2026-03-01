import 'package:kernel_model/kernel_model.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:refractor/src/cli/commands/refractor_command.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';

/// Inspect the contents of a compiled `.dill` file.
///
/// Usage: `refractor inspect [options] <path.dill>`
class InspectCommand extends RefractorCommand {
  InspectCommand({super.logger}) {
    argParser.addFlag(
      'sdk',
      help: 'Include dart:* SDK libraries in the output.',
      negatable: true,
      defaultsTo: false,
    );
  }

  @override
  String get name => 'inspect';

  @override
  String get description => 'Show the contents of a compiled .dill file.';

  @override
  Future<int> run() async {
    final rest = argResults.rest;
    if (rest.isEmpty) {
      usageException('Missing required argument: <path.dill>');
    }
    final path = rest.first;
    final showSdk = argResults.flag('sdk');

    final component = FileKernelIO().load(path);
    final tree = KernelParser().parse(
      component,
      source: path,
      includeSdk: showSdk,
    );
    logger.info(KernelTreePrinter().print(tree));

    return ExitCode.success.code;
  }
}
