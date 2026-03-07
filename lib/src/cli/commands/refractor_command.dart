import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:refractor/src/cli/project_workspace.dart';

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

  /// The current project workspace context.
  ///
  /// Provides access to project root, package name, and build directory.
  ProjectWorkspace get workspace =>
      _workspace ??= ProjectWorkspace(root: Directory.current);

  ProjectWorkspace? _workspace;
  Logger? _logger;
}
