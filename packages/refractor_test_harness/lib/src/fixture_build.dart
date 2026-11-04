import 'dart:io';

import 'package:kernel/kernel.dart' as k;
import 'package:path/path.dart' as p;
import 'package:refractor/refractor.dart';
import 'package:refractor/testing.dart';
import 'package:refractor_test_harness/src/fixture.dart';

/// The product of one obfuscated build: the output path and its metrics.
class ObfuscatedBuild {
  ObfuscatedBuild({required this.outputPath, required this.result});

  final String outputPath;
  final BuildResult result;
}

/// Builds a fixture on demand and memoizes the results, so the three bands
/// can share expensive compilations instead of each rebuilding.
///
/// Every build lands under a single working directory that the caller owns
/// and cleans up.
class FixtureBuild {
  FixtureBuild(this.fixture, this.workDir);

  final Fixture fixture;
  final Directory workDir;

  final _obfuscated = <Target, Future<ObfuscatedBuild>>{};
  final _plain = <Target, String>{};

  /// Builds the fixture through the full Refractor pipeline for [target].
  Future<ObfuscatedBuild> obfuscated(Target target) =>
      _obfuscated.putIfAbsent(target, () => _runEngine(target));

  /// Compiles the fixture source for [target] with no obfuscation, as a
  /// behavioral baseline. Only `exe`, `aot`, and `jit` are runnable targets.
  String plain(Target target) =>
      _plain.putIfAbsent(target, () => _runPlain(target));

  /// Loads the obfuscated kernel [k.Component] for verification.
  Future<k.Component> obfuscatedComponent() async {
    final build = await obfuscated(Target.kernel);
    return FileKernelIO().load(build.outputPath);
  }

  Future<ObfuscatedBuild> _runEngine(Target target) async {
    final output = p.join(workDir.path, 'obf-${_fileName(target)}');
    final engine = RefractorEngine(
      compiler: DartCompiler(),
      kernelIO: FileKernelIO(),
    );
    final result = await engine.run(
      config: fixture.config,
      request: BuildRequest(
        input: fixture.sourcePath,
        output: output,
        target: target,
        workDirectory: _targetWorkDir(target).path,
        projectRootUri: fixture.rootUri,
        projectPackageName: fixture.packageName,
      ),
    );
    return ObfuscatedBuild(outputPath: output, result: result);
  }

  String _runPlain(Target target) {
    final output = p.join(workDir.path, 'plain-${_fileName(target)}');
    // `-o` must precede the source: `dart compile jit-snapshot` passes every
    // argument after the script to the training run, so a trailing `-o` is
    // silently ignored and the snapshot lands next to the source instead.
    final r = Process.runSync(
      Platform.resolvedExecutable,
      ['compile', target.value, '-o', output, fixture.sourcePath],
    );
    if (r.exitCode != 0) {
      throw ProcessException(
        Platform.resolvedExecutable,
        ['compile', target.value],
        'plain build failed: ${r.stderr}',
        r.exitCode,
      );
    }
    return output;
  }

  String _fileName(Target target) {
    final ext = target.extension.isEmpty ? '.exe' : target.extension;
    return '${target.name}$ext';
  }

  Directory _targetWorkDir(Target target) =>
      Directory(p.join(workDir.path, 'work-${target.name}'))
        ..createSync(recursive: true);
}
