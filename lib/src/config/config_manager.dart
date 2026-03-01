import 'dart:io';

import 'package:refractor/src/config/model/refractor_config.dart';

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
      return _defaultConfig();
    }

    final file = File(resolvedPath);
    if (!file.existsSync()) {
      return _defaultConfig();
    }

    final content = file.readAsStringSync();
    if (content.trim().isEmpty) {
      return _defaultConfig();
    }

    return RefractorConfig.fromYaml(content);
  }

  /// Returns a default config with rename + string_encrypt enabled.
  static RefractorConfig _defaultConfig() {
    return RefractorConfig(
      passes: [RenamePassConfig(), StringEncryptPassConfig()],
    );
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
