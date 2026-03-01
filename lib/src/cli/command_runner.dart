import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_completion/cli_completion.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:refractor/src/cli/commands/build_command.dart';
import 'package:refractor/src/cli/commands/init_command.dart';
import 'package:refractor/src/cli/commands/inspect_command.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';

const packageName = 'refractor';
const packageDescription =
    'Dart kernel (.dill) obfuscation tool — rename, encrypt, and obfuscate.';

class RefractorCommandRunner extends CompletionCommandRunner<int> {
  RefractorCommandRunner({Logger? logger})
    : _logger = logger ?? Logger(),
      super(packageName, packageDescription) {
    addCommand(BuildCommand(logger: _logger));
    addCommand(InitCommand(logger: _logger));
    addCommand(InspectCommand(logger: _logger));
  }

  final Logger _logger;

  @override
  void printUsage() => _logger.info(usage);

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults.command?.name == 'completion') {
      await super.runCommand(topLevelResults);
      return ExitCode.success.code;
    }

    return super.runCommand(topLevelResults);
  }

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      return await runCommand(parse(args)) ?? ExitCode.success.code;
    } on RefractorException catch (e) {
      _logger
        ..err(e.message)
        ..info('');
      if (e.cause != null) {
        _logger.detail('Caused by: ${e.cause}');
      }
      return e.exitCode;
    } on FormatException catch (e) {
      _logger
        ..err(e.message)
        ..info('');
      printUsage();
      return ExitCode.usage.code;
    } on UsageException catch (e) {
      _logger
        ..err(e.message)
        ..info('')
        ..info(e.usage);
      return ExitCode.usage.code;
    } on Object catch (e, stackTrace) {
      _logger
        ..err('An unexpected error occurred: $e')
        ..detail(stackTrace.toString());
      return ExitCode.software.code;
    }
  }
}
