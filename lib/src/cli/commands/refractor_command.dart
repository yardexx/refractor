import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

abstract class RefractorCommand extends Command<int> {
  RefractorCommand({Logger? logger}) : _logger = logger;

  @override
  ArgResults get argResults {
    final results = super.argResults;
    if (results == null) {
      throw StateError('Unexpected empty args parse result');
    }

    return results;
  }

  Logger get logger => _logger ??= Logger();

  /// Root directory for all refractor build artifacts and intermediates.
  ///
  /// Created on first access. All commands should work within this directory
  /// to avoid polluting the project or system temp.
  Directory get workspace {
    final dir = Directory('.dart_tool/refractor');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Logger? _logger;
}
