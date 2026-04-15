import 'dart:io';

import 'package:refractor/src/cli/project_workspace.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectWorkspace', () {
    late Directory tempDir;
    late ProjectWorkspace workspace;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('refractor_workspace_');
      workspace = ProjectWorkspace(root: tempDir);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('resolves build output path inside workspace build directory', () {
      expect(
        workspace.primaryOutputPath('.dill'),
        '${tempDir.path}${Platform.pathSeparator}build'
        '${Platform.pathSeparator}out.dill',
      );
    });

    test('resolves relative auxiliary output path inside build directory', () {
      expect(
        workspace.auxiliaryOutputPath('build_artifacts.json'),
        '${tempDir.path}${Platform.pathSeparator}build'
        '${Platform.pathSeparator}build_artifacts.json',
      );
    });

    test('resolves nested auxiliary output path inside build directory', () {
      expect(
        workspace.auxiliaryOutputPath(
          'reports${Platform.pathSeparator}artifacts.json',
        ),
        '${tempDir.path}${Platform.pathSeparator}build'
        '${Platform.pathSeparator}reports'
        '${Platform.pathSeparator}artifacts.json',
      );
    });

    test('preserves absolute auxiliary output path', () {
      final absolutePath =
          '${tempDir.path}${Platform.pathSeparator}artifacts.json';

      expect(
        workspace.auxiliaryOutputPath(absolutePath),
        absolutePath,
      );
    });

    test('creates internal build directory during initialization', () {
      expect(
        Directory(workspace.buildDirectoryPath).existsSync(),
        isTrue,
      );
    });

    test('creates output directory during initialization', () {
      expect(
        Directory(workspace.outputDirectoryPath).existsSync(),
        isTrue,
      );
    });
  });
}
