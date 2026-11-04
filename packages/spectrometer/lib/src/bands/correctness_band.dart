import 'dart:io';

import 'package:kernel/target/targets.dart' as kt;
import 'package:kernel/verifier.dart' as kv;
import 'package:path/path.dart' as p;
import 'package:refractor/refractor.dart';
import 'package:spectrometer/src/bands/band.dart';
import 'package:spectrometer/src/fixture_build.dart';
import 'package:spectrometer/src/spectrum.dart';

/// Checks that a pass *survives the compiler*: the obfuscated kernel is
/// structurally valid, and the obfuscated binary behaves identically to a
/// plain build.
///
/// Two tiers, cheapest first:
///   1. Kernel verifier gate — catches invalid kernel in milliseconds,
///      before paying for a native compile.
///   2. Behavioral equivalence — builds plain and obfuscated for each
///      runnable target, runs both, and diffs stdout.
class CorrectnessBand implements Band {
  const CorrectnessBand();

  @override
  String get name => 'correctness';

  @override
  Future<BandResult> analyze(FixtureBuild build) async {
    final failures = <String>[];
    final readings = <Reading>[];
    final expectations = build.fixture.expectations;

    if (expectations.verifyKernel) {
      try {
        final component = await build.obfuscatedComponent();
        kv.verifyComponent(
          kt.NoneTarget(const kt.TargetFlags()),
          kv.VerificationStage.afterGlobalTransformations,
          component,
          skipPlatform: true,
        );
        readings.add(const Reading('kernel verifier', 'valid'));
      } on Object catch (error) {
        failures.add('kernel verifier rejected obfuscated output: $error');
      }
    }

    if (expectations.checkEquivalence) {
      for (final target in expectations.targets) {
        if (!_runnable(target)) {
          readings.add(Reading('equivalence[${target.name}]', 'skipped'));
          continue;
        }
        try {
          final plain = _run(target, build.plain(target));
          final obfuscated = _run(
            target,
            (await build.obfuscated(target)).outputPath,
          );
          if (plain == obfuscated) {
            readings.add(Reading('equivalence[${target.name}]', 'identical'));
          } else {
            failures.add(
              'stdout differs on ${target.name}:\n'
              '  plain:      ${_oneLine(plain)}\n'
              '  obfuscated: ${_oneLine(obfuscated)}',
            );
          }
        } on Object catch (error) {
          failures.add('build/run failed on ${target.name}: $error');
        }
      }
    }

    return failures.isEmpty
        ? BandResult.passed(name, readings: readings)
        : BandResult.failed(name, failures: failures, readings: readings);
  }

  bool _runnable(Target target) => target != Target.kernel;

  String _run(Target target, String path) {
    final result = switch (target) {
      Target.exe => Process.runSync(path, const []),
      // Run the snapshot directly with the current SDK's VM; `dart run`
      // wants a package context the scratch build directory doesn't have.
      Target.jit => Process.runSync(Platform.resolvedExecutable, [path]),
      Target.aot => Process.runSync(_aotRuntime(), [path]),
      Target.kernel => throw ArgumentError('kernel is not runnable'),
    };
    if (result.exitCode != 0) {
      throw ProcessException(
        path,
        const [],
        'exit ${result.exitCode}: ${result.stderr}',
        result.exitCode,
      );
    }
    return (result.stdout as String).trim();
  }

  String _aotRuntime() {
    final sdkBin = File(Platform.resolvedExecutable).parent;
    final sibling = File(p.join(sdkBin.path, 'dartaotruntime'));
    if (sibling.existsSync()) return sibling.path;
    return 'dartaotruntime';
  }

  String _oneLine(String value) => value.replaceAll('\n', ' | ');
}
