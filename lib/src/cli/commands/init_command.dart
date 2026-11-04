import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

/// Scaffolds a `refractor.yaml` template in the current directory.
class InitCommand extends Command<int> {
  InitCommand({Logger? logger}) : _logger = logger ?? Logger() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output path for the config file',
      defaultsTo: 'refractor.yaml',
    );
  }

  final Logger _logger;

  @override
  String get name => 'init';

  @override
  String get description => 'Create a refractor.yaml config template.';

  @override
  Future<int> run() async {
    final outputPath = argResults!['output'] as String;
    final file = File(outputPath);

    if (file.existsSync()) {
      _logger.warn('$outputPath already exists. Overwrite?');
      final overwrite = _logger.confirm('Overwrite?');
      if (!overwrite) {
        _logger.info('Aborted.');
        return ExitCode.success.code;
      }
    }

    file.writeAsStringSync(_defaultTemplate);
    _logger.success('Created $outputPath');
    return ExitCode.success.code;
  }
}

const _defaultTemplate = '''
# Refractor configuration
# Modeled after analysis_options.yaml for Dart developer familiarity.
# See: https://github.com/yardexx/refractor

refractor:
  # Library URI/path exclusions using glob patterns.
  # exclude:
  #   - "**/*.g.dart"
  #   - "**/*.freezed.dart"

  passes:
    rename:
      enabled: true
      # exclude:
      #   - "lib/src/public_api/**"

    string_encrypt:
      enabled: true
      # seed: 0x5A
      # exclude:
      #   - "lib/src/logging/**"
      # exclude_patterns:
      #   - "^https://"
''';
