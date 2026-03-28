import 'package:kernel/ast.dart';

final class ProjectScope {
  const ProjectScope({
    required this.projectRootUri,
    required this.projectPackageName,
  });

  final Uri projectRootUri;
  final String? projectPackageName;

  bool containsLibrary(Library library) {
    return workspacePathForLibrary(library) != null;
  }

  String? workspacePathForLibrary(Library library) {
    final uri = library.importUri;
    if (uri.scheme == 'dart') {
      return null;
    }

    if (uri.scheme == 'package') {
      if (projectPackageName == null || uri.pathSegments.isEmpty) {
        return null;
      }

      final packageName = uri.pathSegments.first;
      if (packageName != projectPackageName) {
        return null;
      }

      final relativePath = uri.pathSegments.skip(1).join('/');
      return relativePath.isEmpty ? 'lib' : 'lib/$relativePath';
    }

    if (uri.scheme == 'file') {
      if (projectRootUri.scheme != 'file') {
        return null;
      }

      final rootPath = _normalizeFilePath(projectRootUri.toFilePath());
      final filePath = _normalizeFilePath(uri.toFilePath());
      if (filePath == rootPath) {
        return '';
      }
      if (!filePath.startsWith('$rootPath/')) {
        return null;
      }
      return filePath.substring(rootPath.length + 1);
    }

    return null;
  }

  static String _normalizeFilePath(String input) {
    final normalized = input.replaceAll(r'\', '/');
    if (normalized.endsWith('/') && normalized.length > 1) {
      return normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
