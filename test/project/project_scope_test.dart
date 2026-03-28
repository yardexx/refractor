import 'package:kernel/ast.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectScope', () {
    final scope = ProjectScope(
      projectRootUri: Uri(scheme: 'file', path: '/virtual/project/'),
      projectPackageName: 'refractor',
    );

    test('maps project package libraries to workspace paths', () {
      final library = Library(
        Uri.parse('package:refractor/src/app.dart'),
        fileUri: Uri.parse('package:refractor/src/app.dart'),
      );

      expect(scope.containsLibrary(library), isTrue);
      expect(scope.workspacePathForLibrary(library), 'lib/src/app.dart');
    });

    test(
      'maps file libraries under project root to relative workspace paths',
      () {
        final library = Library(
          Uri.parse('file:///virtual/project/lib/src/file_app.dart'),
          fileUri: Uri.parse('file:///virtual/project/lib/src/file_app.dart'),
        );

        expect(scope.containsLibrary(library), isTrue);
        expect(scope.workspacePathForLibrary(library), 'lib/src/file_app.dart');
      },
    );

    test('rejects external package and sdk libraries', () {
      final external = Library(
        Uri.parse('package:other_pkg/src/app.dart'),
        fileUri: Uri.parse('package:other_pkg/src/app.dart'),
      );
      final sdk = Library(
        Uri.parse('dart:core'),
        fileUri: Uri.parse('dart:core'),
      );

      expect(scope.containsLibrary(external), isFalse);
      expect(scope.containsLibrary(sdk), isFalse);
      expect(scope.workspacePathForLibrary(external), isNull);
      expect(scope.workspacePathForLibrary(sdk), isNull);
    });

    test('rejects file libraries outside project root', () {
      final library = Library(
        Uri.parse('file:///elsewhere/project/lib/src/app.dart'),
        fileUri: Uri.parse('file:///elsewhere/project/lib/src/app.dart'),
      );

      expect(scope.containsLibrary(library), isFalse);
      expect(scope.workspacePathForLibrary(library), isNull);
    });
  });
}
