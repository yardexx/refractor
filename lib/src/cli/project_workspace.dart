import 'dart:io';

import 'package:refractor/src/engine/engine.dart';
import 'package:yaml/yaml.dart' show YamlMap, loadYaml;

/// Represents the current Dart/Flutter project context.
///
/// Encapsulates project root detection, package name resolution from
/// `pubspec.yaml`, and the build artifact directory.
class ProjectWorkspace {
  ProjectWorkspace({required this.root})
    : packageName = _detectPackageName(root),
      outputDirectory = Directory(
        '${root.path}${Platform.pathSeparator}build',
      ),
      buildDirectory = Directory(
        '${root.path}${Platform.pathSeparator}.dart_tool'
        '${Platform.pathSeparator}refractor',
      ) {
    _ensureDirectory(outputDirectory);
    _ensureDirectory(buildDirectory);
  }

  final Directory root;
  final String? packageName;
  final Directory outputDirectory;
  final Directory buildDirectory;

  Uri get rootUri => root.uri;

  String get outputDirectoryPath => outputDirectory.path;
  String get buildDirectoryPath => buildDirectory.path;

  String primaryOutputPath(String targetExtension) {
    return '$outputDirectoryPath${Platform.pathSeparator}out$targetExtension';
  }

  String auxiliaryOutputPath(String configuredPath) {
    final file = File(configuredPath);
    if (file.isAbsolute) {
      return configuredPath;
    }

    return '$outputDirectoryPath${Platform.pathSeparator}$configuredPath';
  }

  /// Builds the engine's [BuildRequest] from this workspace.
  ///
  /// The adapter lives here, on the CLI side, so the dependency runs
  /// cli -> engine (the correct direction). The engine's [BuildRequest] stays
  /// a plain DTO with no knowledge of the workspace or filesystem.
  BuildRequest toBuildRequest({
    required String input,
    required Target target,
  }) {
    return BuildRequest(
      input: input,
      output: primaryOutputPath(target.extension),
      target: target,
      workDirectory: buildDirectory.path,
      projectRootUri: root.uri,
      projectPackageName: packageName,
    );
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

  static void _ensureDirectory(Directory directory) {
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
  }
}
