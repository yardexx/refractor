import 'package:glob/glob.dart';
import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/runner/obfuscation_target.dart';
import 'package:test/test.dart';

void main() {
  group('ObfuscationTarget.shouldObfuscateLibrary', () {
    ObfuscationTarget makeTarget({
      Uri? projectRootUri,
      String? projectPackageName = 'my_app',
      List<Glob> excludePatterns = const [],
    }) {
      return ObfuscationTarget(
        projectRootUri: projectRootUri ?? Uri.file('/project/'),
        projectPackageName: projectPackageName,
        excludePatterns: excludePatterns,
      );
    }

    Library makeLibrary(String uri) {
      final parsed = Uri.parse(uri);
      return Library(parsed, fileUri: parsed);
    }

    test('never obfuscates dart: libraries', () {
      final target = makeTarget();
      expect(
        target.shouldObfuscateLibrary(makeLibrary('dart:core')),
        isFalse,
      );
    });

    test('rejects non-project package libraries', () {
      final target = makeTarget();
      expect(
        target.shouldObfuscateLibrary(
          makeLibrary('package:other_package/main.dart'),
        ),
        isFalse,
      );
    });

    test('obfuscates only files inside current project folder', () {
      final target = makeTarget(projectRootUri: Uri.file('/project/'));
      final inProjectUri = Uri.file('/project/lib/main.dart');

      expect(
        target.shouldObfuscateLibrary(
          makeLibrary(inProjectUri.toString()),
        ),
        isTrue,
      );
      expect(
        target.shouldObfuscateLibrary(
          makeLibrary('file:///another/place/lib/main.dart'),
        ),
        isFalse,
      );
    });

    test('exclude patterns can block by import URI string', () {
      final target = makeTarget(
        excludePatterns: [Glob('**/generated/**')],
      );

      expect(
        target.shouldObfuscateLibrary(
          makeLibrary('package:my_app/generated/file.dart'),
        ),
        isFalse,
      );
    });

    test('rejects non-project file URIs by default', () {
      final target = makeTarget();
      expect(
        target.shouldObfuscateLibrary(
          makeLibrary('file:///outside/project/main.dart'),
        ),
        isFalse,
      );
    });

    test('skips all package libraries when project package is unknown', () {
      final target = makeTarget(projectPackageName: null);
      expect(
        target.shouldObfuscateLibrary(
          makeLibrary('package:my_app/main.dart'),
        ),
        isFalse,
      );
    });
  });
}
