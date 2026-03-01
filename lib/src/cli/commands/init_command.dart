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

# Global tool settings.
refractor:
  # Output path for the symbol map (original → obfuscated name mapping).
  # symbol_map: build/refractor_map.json

  # Scope is fixed to the current project (pubspec package + current folder).

  # Library URI/path exclusions using glob patterns.
  # exclude:
  #   - "**/*.g.dart"
  #   - "**/*.freezed.dart"

# Pass configuration — enable/disable and configure each pass.
# Use `true` for defaults, `false` to disable, or a map for custom settings.
passes:
  rename:
    # preserve_main: true

  string_encrypt: true
  # string_encrypt:
  #   xor_key: 0x5A
  #   exclude_patterns:
  #     - "^https://"

  dead_code: false

# Verbose logging.
# verbose: false
''';
