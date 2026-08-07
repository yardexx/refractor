import 'package:kernel/ast.dart';

final class ProjectScope {
  ProjectScope({
    required this.projectRootUri,
    required this.projectPackageName,
  });

  final Uri projectRootUri;
  final String? projectPackageName;

  /// Memoizes the workspace path per library. Membership is queried once per
  /// node during selection/transformation, so caching turns each check into an
  /// O(1) lookup instead of recomputing the URI path every time. Keyed by
  /// [Library] identity, which is stable for the lifetime of one build.
  final Map<Library, String?> _workspacePathCache = {};

  bool containsLibrary(Library library) {
    return workspacePathForLibrary(library) != null;
  }

  String? workspacePathForLibrary(Library library) {
    final cached = _workspacePathCache[library];
    if (cached != null || _workspacePathCache.containsKey(library)) {
      return cached;
    }
    return _workspacePathCache[library] = _computeWorkspacePath(library);
  }

  String? _computeWorkspacePath(Library library) {
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
