import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/name_generator.dart';
import 'package:refractor/src/engine/runner/pass_options.dart';
import 'package:refractor/src/engine/symbol_table.dart';

/// Shared mutable context passed to every obfuscation pass.
class PassContext {
  PassContext({
    required this.symbolTable,
    required this.nameGenerator,
    required this.options,
    required this.projectRootUri,
    required this.projectPackageName,
  });
  final SymbolTable symbolTable;
  final NameGenerator nameGenerator;
  final PassOptions options;
  final Uri projectRootUri;
  final String? projectPackageName;

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
      // When the project package name is unknown, we cannot safely
      // distinguish user code from third-party dependencies, so we
      // skip all package: libraries to avoid breaking deps.
      if (projectPackageName == null) return false;
      final packageName = uri.pathSegments.isEmpty
          ? null
          : uri.pathSegments.first;
      return packageName == projectPackageName;
    }

    if (uri.scheme == 'file') {
      if (projectRootUri.scheme != 'file') return false;
      final rootPath = _normalizeFilePath(projectRootUri.toFilePath());
      final filePath = _normalizeFilePath(uri.toFilePath());
      return filePath == rootPath || filePath.startsWith('$rootPath/');
    }

    return false;
  }

  static String _normalizeFilePath(String input) {
    final normalized = input.replaceAll(r'\', '/');
    if (normalized.endsWith('/') && normalized.length > 1) {
      return normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
