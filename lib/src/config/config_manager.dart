import 'dart:io';

import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';

class ConfigManager {
  /// Default config file name.
  static const defaultConfigName = 'refractor.yaml';

  /// Loads a [RefractorConfig] from a config file on disk.
  ///
  /// If [configPath] points to a specific file, that file is loaded.
  /// If [configPath] is empty, searches for `refractor.yaml` in the current
  /// directory.
  static RefractorConfig loadConfig({String configPath = ''}) {
    final resolvedPath = _resolveConfigPath(configPath);

    if (resolvedPath == null) {
      final target = configPath.isNotEmpty ? configPath : defaultConfigName;
      throw ConfigException(
        'Configuration file not found: ${File(target).absolute.path}\n'
        'Run "refractor init" to create one.',
      );
    }

    final file = File(resolvedPath);
    if (!file.existsSync()) {
      throw ConfigException(
        'Configuration file not found: ${file.absolute.path}\n'
        'Run "refractor init" to create one.',
      );
    }

    final content = file.readAsStringSync();
    if (content.trim().isEmpty) {
      throw ConfigException(
        'Configuration file is empty: ${file.absolute.path}',
      );
    }

    try {
      return RefractorConfig.fromYaml(content);
    } on ConfigException catch (e) {
      throw ConfigException(
        'Invalid configuration at ${file.absolute.path}: ${e.message}',
        cause: e.cause,
      );
    }
  }

  /// Find the config file path. Returns null if none found.
  static String? _resolveConfigPath(String configPath) {
    if (configPath.isNotEmpty) {
      if (File(configPath).existsSync()) return configPath;
      // If user specified a path but it doesn't exist, don't search further.
      return null;
    }

    // Search default name.
    if (File(defaultConfigName).existsSync()) return defaultConfigName;
    return null;
  }
}
