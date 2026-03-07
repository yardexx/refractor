import 'dart:io';

import 'package:yaml/yaml.dart' show YamlMap, loadYaml;

/// Represents the current Dart/Flutter project context.
///
/// Encapsulates project root detection, package name resolution from
/// `pubspec.yaml`, and the build artifact directory.
class ProjectWorkspace {
  ProjectWorkspace({required this.root})
    : packageName = _detectPackageName(root),
      buildDirectory = Directory(
        '${root.path}${Platform.pathSeparator}.dart_tool'
        '${Platform.pathSeparator}refractor',
      );

  final Directory root;
  final String? packageName;
  final Directory buildDirectory;

  Uri get rootUri => root.uri;

  void ensureBuildDirectory() {
    if (!buildDirectory.existsSync()) {
      buildDirectory.createSync(recursive: true);
    }
  }

  static String? _detectPackageName(Directory root) {
    final pubspec = File(
      '${root.path}${Platform.pathSeparator}pubspec.yaml',
    );
    if (!pubspec.existsSync()) return null;
    try {
      final yaml = loadYaml(pubspec.readAsStringSync());
      if (yaml is! YamlMap) return null;
      final name = yaml['name'];
      return name is String && name.isNotEmpty ? name : null;
    } on Exception {
      return null;
    }
  }
}
