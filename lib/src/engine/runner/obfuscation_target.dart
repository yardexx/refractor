import 'package:glob/glob.dart';
import 'package:kernel/kernel.dart';

/// Read-only shared context: "which libraries should I transform?"
///
/// Every pass receives the same target. This is a property of the project
/// being obfuscated, not of any individual pass.
class ObfuscationTarget {
  ObfuscationTarget({
    required this.projectRootUri,
    this.projectPackageName,
    this.excludePatterns = const [],
  });

  final Uri projectRootUri;
  final String? projectPackageName;
  final List<Glob> excludePatterns;

  /// Returns true if [library] belongs to user code that should be obfuscated.
  bool shouldObfuscateLibrary(Library library) {
    final uri = library.importUri;
    // Never touch SDK libraries.
    if (uri.scheme == 'dart') return false;

    final uriText = uri.toString();
    for (final glob in excludePatterns) {
      if (glob.matches(uriText)) return false;
      if (glob.matches(uri.path)) return false;
    }

    if (uri.scheme == 'package') {
      // When the project package name is unknown, we cannot safely
      // distinguish user code from third-party dependencies, so we
      // skip all package: libraries to avoid breaking deps.
      if (projectPackageName == null) return false;
      final packageName =
          uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
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
