import 'dart:io';

import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/name_generator.dart';
import 'package:refractor/src/engine/runner/pass_options.dart';
import 'package:refractor/src/engine/symbol_table.dart';
import 'package:yaml/yaml.dart';

/// Shared mutable context passed to every obfuscation pass.
class PassContext {
  PassContext({
    required this.symbolTable,
    required this.nameGenerator,
    required this.options,
  }) : _projectRootPath = Directory.current.absolute.path,
       _projectPackage = _detectProjectPackage(Directory.current);
  final SymbolTable symbolTable;
  final NameGenerator nameGenerator;
  final PassOptions options;
  final String _projectRootPath;
  final String? _projectPackage;

  /// Returns true if [library] belongs to user code that should be obfuscated.
  bool shouldObfuscateLibrary(Library library) {
    final uri = library.importUri;
    // Never touch SDK libraries.
    if (uri.scheme == 'dart') return false;

    final uriText = uri.toString();
    for (final glob in options.excludeLibraryUriPatterns) {
      if (glob.matches(uriText)) return false;
      if (glob.matches(uri.path)) return false;
    }

    if (uri.scheme == 'package') {
      final packageName = uri.pathSegments.isEmpty
          ? null
          : uri.pathSegments.first;
      return packageName != null && packageName == _projectPackage;
    }

    if (uri.scheme == 'file') {
      final root = _projectRootPath;
      final filePath = uri.toFilePath();
      return filePath == root ||
          filePath.startsWith('$root${Platform.pathSeparator}');
    }

    return false;
  }

  static String? _detectProjectPackage(Directory cwd) {
    final pubspec = File('${cwd.path}${Platform.pathSeparator}pubspec.yaml');
    if (!pubspec.existsSync()) return null;
    try {
      final yaml = loadYaml(pubspec.readAsStringSync());
      if (yaml is! YamlMap) return null;
      final name = yaml['name'];
      return name is String && name.isNotEmpty ? name : null;
    } on Object {
      return null;
    }
  }
}
