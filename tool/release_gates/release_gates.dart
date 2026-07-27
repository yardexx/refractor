import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:refractor/src/cli/commands/build_command.dart';
import 'package:refractor/src/cli/pass_results_io.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/compiler/compiler.dart' as compiler;
import 'package:refractor/src/engine/compiler/dart_compiler.dart';
import 'package:refractor/src/engine/engine.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';
import 'package:refractor/src/engine/passes/rename/reporting/rename_artifact.dart';

const releaseGateFixtureName = 'release-gates-smoke';

const releaseGateFixtureSource = r'''
void main() {
  final renderer = Renderer('Hello');
  final values = ['alpha', 'beta', 'gamma'];
  print(renderer.render('World'));
  print('values=${values.map((value) => value.toUpperCase()).join('|')}');
  print('secret=vault-token');
}

class Renderer {
  Renderer(this.prefix);

  final String prefix;

  String render(String value) => '$prefix $value';
}
''';

const releaseGateConfigYaml = '''
refractor:
  verbose: false
  artifact_json: release_gates/artifacts.json
  passes:
    rename:
      seed: 1337
    string_encrypt:
      xor_key: 42
''';

enum ReleaseGateStatus {
  passed,
  failed,
  blocked
  ;

  String toJson() => name;
}

enum ReleaseGateTarget {
  exe('exe', ''),
  jit('jit', '.jit'),
  aot('aot', '.aot')
  ;

  const ReleaseGateTarget(this.value, this.extension);

  factory ReleaseGateTarget.parse(String value) {
    for (final target in values) {
      if (target.value == value) {
        return target;
      }
    }

    throw FormatException(
      'Unknown release-gate target "$value". Expected exe, jit, or aot.',
    );
  }

  final String value;
  final String extension;

  compiler.Target get compilerTarget => switch (this) {
    ReleaseGateTarget.exe => compiler.Target.exe,
    ReleaseGateTarget.jit => compiler.Target.jit,
    ReleaseGateTarget.aot => compiler.Target.aot,
  };

  String get compileValue => compilerTarget.value;
}

class HardGateResult {
  const HardGateResult({
    required this.id,
    required this.name,
    required this.status,
    required this.message,
    this.evidence = const {},
  });

  final String id;
  final String name;
  final ReleaseGateStatus status;
  final String message;
  final Map<String, Object?> evidence;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'status': status.toJson(),
    'message': message,
    if (evidence.isNotEmpty) 'evidence': evidence,
  };
}

class BudgetMeasurement {
  const BudgetMeasurement({
    required this.id,
    required this.name,
    required this.unit,
    required this.baseline,
    required this.candidate,
  });

  final String id;
  final String name;
  final String unit;
  final num baseline;
  final num candidate;

  num get delta => candidate - baseline;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'unit': unit,
    'baseline': baseline,
    'candidate': candidate,
    'delta': delta,
  };
}

class TargetValidationResult {
  const TargetValidationResult({
    required this.target,
    required this.gates,
    required this.budgets,
  });

  final ReleaseGateTarget target;
  final List<HardGateResult> gates;
  final List<BudgetMeasurement> budgets;

  Map<String, Object?> toJson() => {
    'target': target.value,
    'gates': [for (final gate in gates) gate.toJson()],
    'budgets': [for (final budget in budgets) budget.toJson()],
  };
}

class ReleaseGateReport {
  const ReleaseGateReport({
    required this.generatedAt,
    required this.dartVersion,
    required this.hostOs,
    required this.fixtureName,
    required this.targets,
    required this.globalGates,
  });

  final DateTime generatedAt;
  final String dartVersion;
  final String hostOs;
  final String fixtureName;
  final List<TargetValidationResult> targets;
  final List<HardGateResult> globalGates;

  List<HardGateResult> get hardGates => [
    ...globalGates,
    for (final target in targets) ...target.gates,
  ];

  ReleaseGateStatus get status {
    if (hardGates.any((gate) => gate.status == ReleaseGateStatus.failed)) {
      return ReleaseGateStatus.failed;
    }
    if (hardGates.any((gate) => gate.status == ReleaseGateStatus.blocked)) {
      return ReleaseGateStatus.blocked;
    }

    return ReleaseGateStatus.passed;
  }

  bool get hasFailures => status == ReleaseGateStatus.failed;

  bool get isFullSignoffReady => status == ReleaseGateStatus.passed;

  Map<String, Object?> toJson() => {
    'schema': 'refractor.release_gates/v1',
    'generated_at': generatedAt.toUtc().toIso8601String(),
    'status': status.toJson(),
    'dart_version': dartVersion,
    'host_os': hostOs,
    'fixture_name': fixtureName,
    'global_gates': [for (final gate in globalGates) gate.toJson()],
    'targets': [for (final target in targets) target.toJson()],
  };

  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}

abstract interface class ReleaseGateProbe {
  Future<TargetValidationResult> validateTarget(
    ReleaseGateTarget target,
    Directory workDirectory,
  );

  Future<HardGateResult> validateArtifactGate(Directory workDirectory);

  Future<HardGateResult> validateDeterminismGate(Directory workDirectory);
}

class ReleaseGateRunner {
  const ReleaseGateRunner({
    required ReleaseGateProbe probe,
    Clock clock = const SystemClock(),
  }) : _probe = probe,
       _clock = clock;

  final ReleaseGateProbe _probe;
  final Clock _clock;

  Future<ReleaseGateReport> run({
    List<ReleaseGateTarget> targets = ReleaseGateTarget.values,
    bool includeBlocked = true,
    Directory? workDirectory,
  }) async {
    final root =
        workDirectory ??
        Directory.systemTemp.createTempSync(
          'refractor_release_gates_',
        );

    final targetResults = <TargetValidationResult>[];
    for (final target in targets) {
      targetResults.add(await _probe.validateTarget(target, root));
    }

    final globalGates = <HardGateResult>[
      _requiredTargetGate(targets),
      await _probe.validateArtifactGate(root),
      await _probe.validateDeterminismGate(root),
      if (includeBlocked) ..._blockedDependencyGates(),
    ];

    return ReleaseGateReport(
      generatedAt: _clock.now(),
      dartVersion: Platform.version,
      hostOs: Platform.operatingSystem,
      fixtureName: releaseGateFixtureName,
      targets: targetResults,
      globalGates: globalGates,
    );
  }

  HardGateResult _requiredTargetGate(List<ReleaseGateTarget> targets) {
    final values = targets.map((target) => target.value).toSet();
    final missing = ReleaseGateTarget.values
        .where((target) => !values.contains(target.value))
        .map((target) => target.value)
        .toList(growable: false);

    if (missing.isNotEmpty) {
      return HardGateResult(
        id: 'required_targets',
        name: 'Mandatory Runtime Targets',
        status: ReleaseGateStatus.blocked,
        message: 'Full signoff requires exe, jit, and aot validation.',
        evidence: {
          'required': [
            for (final target in ReleaseGateTarget.values) target.value,
          ],
          'validated': [for (final target in targets) target.value],
          'missing': missing,
        },
      );
    }

    return const HardGateResult(
      id: 'required_targets',
      name: 'Mandatory Runtime Targets',
      status: ReleaseGateStatus.passed,
      message: 'All mandatory runtime targets were selected for validation.',
    );
  }

  List<HardGateResult> _blockedDependencyGates() => const [
    HardGateResult(
      id: 'dry_run_workflow',
      name: 'Dry-Run Workflow',
      status: ReleaseGateStatus.blocked,
      message: 'Blocked until docs/features/development/05-dry-run.md lands.',
      evidence: {
        'feature_doc': 'docs/features/development/05-dry-run.md',
      },
    ),
    HardGateResult(
      id: 'symbolication_workflow',
      name: 'Symbolication Workflow',
      status: ReleaseGateStatus.blocked,
      message: 'Blocked until symbolication workflow implementation lands.',
      evidence: {
        'feature_doc':
            'docs/features/development/06-symbolication-and-crash-workflow.md',
      },
    ),
  ];
}

abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

class RealReleaseGateProbe implements ReleaseGateProbe {
  const RealReleaseGateProbe();

  @override
  Future<TargetValidationResult> validateTarget(
    ReleaseGateTarget target,
    Directory workDirectory,
  ) async {
    final targetDir = Directory(p.join(workDirectory.path, target.value))
      ..createSync(recursive: true);
    final sourcePath = p.join(targetDir.path, 'main.dart');
    File(sourcePath).writeAsStringSync(releaseGateFixtureSource);

    try {
      final baseline = _compileAndRunBaseline(
        target: target,
        sourcePath: sourcePath,
        outputPath: p.join(targetDir.path, 'baseline${target.extension}'),
        workingDirectory: targetDir.path,
      );
      final candidate = await _compileAndRunCandidate(
        target: target,
        sourcePath: sourcePath,
        outputPath: p.join(targetDir.path, 'candidate${target.extension}'),
        workDirectory: p.join(targetDir.path, 'candidate_work'),
        projectRootUri: targetDir.uri,
      );

      final passed =
          baseline.exitCode == 0 &&
          candidate.exitCode == 0 &&
          baseline.stdout.trim() == candidate.stdout.trim();

      return TargetValidationResult(
        target: target,
        gates: [
          HardGateResult(
            id: 'correctness_${target.value}',
            name: 'Correctness On ${target.value}',
            status: passed
                ? ReleaseGateStatus.passed
                : ReleaseGateStatus.failed,
            message: passed
                ? 'Baseline and candidate output matched.'
                : 'Baseline and candidate output differed or execution failed.',
            evidence: {
              'baseline_exit_code': baseline.exitCode,
              'candidate_exit_code': candidate.exitCode,
              'baseline_stdout': baseline.stdout.trim(),
              'candidate_stdout': candidate.stdout.trim(),
              'candidate_output': candidate.outputPath,
            },
          ),
        ],
        budgets: [
          BudgetMeasurement(
            id: 'compile_time_${target.value}',
            name: 'Compile Time',
            unit: 'milliseconds',
            baseline: baseline.compileMilliseconds,
            candidate: candidate.compileMilliseconds,
          ),
          BudgetMeasurement(
            id: 'runtime_${target.value}',
            name: 'Runtime',
            unit: 'milliseconds',
            baseline: baseline.runtimeMilliseconds,
            candidate: candidate.runtimeMilliseconds,
          ),
          BudgetMeasurement(
            id: 'binary_size_${target.value}',
            name: 'Binary Size',
            unit: 'bytes',
            baseline: baseline.outputBytes,
            candidate: candidate.outputBytes,
          ),
        ],
      );
    } on Object catch (error) {
      return TargetValidationResult(
        target: target,
        gates: [
          HardGateResult(
            id: 'correctness_${target.value}',
            name: 'Correctness On ${target.value}',
            status: ReleaseGateStatus.failed,
            message: 'Validation failed before output comparison: $error',
          ),
        ],
        budgets: const [],
      );
    }
  }

  @override
  Future<HardGateResult> validateArtifactGate(Directory workDirectory) async {
    final projectDir = Directory(p.join(workDirectory.path, 'artifact_gate'))
      ..createSync(recursive: true);
    Directory(p.join(projectDir.path, 'lib')).createSync(recursive: true);
    File(p.join(projectDir.path, 'pubspec.yaml')).writeAsStringSync(
      'name: release_gate_artifact_fixture\n',
    );
    File(p.join(projectDir.path, 'refractor.yaml')).writeAsStringSync(
      releaseGateConfigYaml,
    );
    File(p.join(projectDir.path, 'lib', 'main.dart')).writeAsStringSync(
      releaseGateFixtureSource,
    );

    final originalCurrent = Directory.current;
    try {
      Directory.current = projectDir;
      final runner = CommandRunner<int>(
        'release-gates',
        'release gate validation',
      )..addCommand(BuildCommand(logger: Logger()));

      final exitCode = await runner.run([
        'build',
        '--target',
        'kernel',
        '--input',
        'lib/main.dart',
      ]);
      final artifactPath = p.join(
        projectDir.path,
        'build',
        'release_gates',
        'artifacts.json',
      );
      final artifactFile = File(artifactPath);
      if (exitCode != ExitCode.success.code || !artifactFile.existsSync()) {
        return HardGateResult(
          id: 'artifact_ownership',
          name: 'Artifact Ownership And Output Consistency',
          status: ReleaseGateStatus.failed,
          message: 'BuildCommand did not write the configured artifact JSON.',
          evidence: {
            'exit_code': exitCode,
            'artifact_path': artifactPath,
          },
        );
      }

      final json = jsonDecode(artifactFile.readAsStringSync());
      final hasGenericShape =
          json is Map<String, Object?> &&
          json['passes'] is Map<String, Object?>;

      return HardGateResult(
        id: 'artifact_ownership',
        name: 'Artifact Ownership And Output Consistency',
        status: hasGenericShape
            ? ReleaseGateStatus.passed
            : ReleaseGateStatus.failed,
        message: hasGenericShape
            ? 'BuildCommand wrote generic combined artifact JSON.'
            : 'Artifact JSON did not use the generic top-level passes shape.',
        evidence: {
          'artifact_path': artifactPath,
        },
      );
    } on Object catch (error) {
      return HardGateResult(
        id: 'artifact_ownership',
        name: 'Artifact Ownership And Output Consistency',
        status: ReleaseGateStatus.failed,
        message: 'Artifact gate failed: $error',
      );
    } finally {
      Directory.current = originalCurrent;
    }
  }

  @override
  Future<HardGateResult> validateDeterminismGate(
    Directory workDirectory,
  ) async {
    try {
      final first = await _renameArtifactJson(
        workDirectory: Directory(p.join(workDirectory.path, 'determinism_1'))
          ..createSync(recursive: true),
      );
      final second = await _renameArtifactJson(
        workDirectory: Directory(p.join(workDirectory.path, 'determinism_2'))
          ..createSync(recursive: true),
      );
      final passed = first == second;

      return HardGateResult(
        id: 'fixed_seed_determinism',
        name: 'Fixed-Seed Rename Determinism',
        status: passed ? ReleaseGateStatus.passed : ReleaseGateStatus.failed,
        message: passed
            ? 'Fixed-seed rename artifact was stable across two builds.'
            : 'Fixed-seed rename artifact differed across two builds.',
      );
    } on Object catch (error) {
      return HardGateResult(
        id: 'fixed_seed_determinism',
        name: 'Fixed-Seed Rename Determinism',
        status: ReleaseGateStatus.failed,
        message: 'Determinism validation failed: $error',
      );
    }
  }

  _RunMeasurement _compileAndRunBaseline({
    required ReleaseGateTarget target,
    required String sourcePath,
    required String outputPath,
    required String workingDirectory,
  }) {
    final compileWatch = Stopwatch()..start();
    final compileResult = Process.runSync(
      'dart',
      ['compile', target.compileValue, sourcePath, '-o', outputPath],
      workingDirectory: workingDirectory,
    );
    compileWatch.stop();

    if (compileResult.exitCode != 0) {
      throw StateError(
        'Baseline ${target.value} compile failed: ${compileResult.stderr}',
      );
    }

    final resolvedOutputPath = _resolveCompiledOutput(
      requestedOutputPath: outputPath,
      fallbackOutputPath:
          '${p.withoutExtension(sourcePath)}${target.extension}',
    );
    final run = _runOutput(target: target, outputPath: resolvedOutputPath);
    return _RunMeasurement(
      outputPath: resolvedOutputPath,
      exitCode: run.exitCode,
      stdout: run.stdout?.toString() ?? '',
      compileMilliseconds: compileWatch.elapsedMilliseconds,
      runtimeMilliseconds: run.runtimeMilliseconds,
      outputBytes: File(resolvedOutputPath).lengthSync(),
    );
  }

  Future<_RunMeasurement> _compileAndRunCandidate({
    required ReleaseGateTarget target,
    required String sourcePath,
    required String outputPath,
    required String workDirectory,
    required Uri projectRootUri,
  }) async {
    Directory(workDirectory).createSync(recursive: true);
    final config = RefractorConfig.fromYaml(releaseGateConfigYaml);
    final engine = RefractorEngine(
      compiler: DartCompiler(),
      kernelIO: FileKernelIO(),
    );

    final compileWatch = Stopwatch()..start();
    final result = await engine.run(
      config: config,
      request: BuildRequest(
        input: sourcePath,
        output: outputPath,
        target: target.compilerTarget,
        workDirectory: workDirectory,
        projectRootUri: projectRootUri,
        projectPackageName: null,
      ),
    );
    compileWatch.stop();

    if (result.failures.isNotEmpty) {
      throw StateError('Candidate build reported pass failures.');
    }

    if (result.passResults.hasArtifacts) {
      result.passResults.writeArtifactsToPath(
        p.join(workDirectory, 'build_artifacts.json'),
      );
    }

    final run = _runOutput(target: target, outputPath: outputPath);
    return _RunMeasurement(
      outputPath: outputPath,
      exitCode: run.exitCode,
      stdout: run.stdout?.toString() ?? '',
      compileMilliseconds: compileWatch.elapsedMilliseconds,
      runtimeMilliseconds: run.runtimeMilliseconds,
      outputBytes: File(outputPath).lengthSync(),
    );
  }

  _TimedProcessResult _runOutput({
    required ReleaseGateTarget target,
    required String outputPath,
  }) {
    final watch = Stopwatch()..start();
    final result = switch (target) {
      ReleaseGateTarget.exe => Process.runSync(outputPath, []),
      ReleaseGateTarget.jit => Process.runSync('dart', ['run', outputPath]),
      ReleaseGateTarget.aot => Process.runSync(
        _findDartAotRuntime(),
        [outputPath],
      ),
    };
    watch.stop();

    return _TimedProcessResult(
      exitCode: result.exitCode,
      stdout: result.stdout,
      stderr: result.stderr,
      runtimeMilliseconds: watch.elapsedMilliseconds,
    );
  }

  String _resolveCompiledOutput({
    required String requestedOutputPath,
    required String fallbackOutputPath,
  }) {
    if (File(requestedOutputPath).existsSync()) {
      return requestedOutputPath;
    }

    final fallbackOutput = File(fallbackOutputPath);
    if (fallbackOutput.existsSync()) {
      fallbackOutput.renameSync(requestedOutputPath);
      return requestedOutputPath;
    }

    return requestedOutputPath;
  }

  Future<String> _renameArtifactJson({
    required Directory workDirectory,
  }) async {
    final sourcePath = p.join(workDirectory.path, 'main.dart');
    File(sourcePath).writeAsStringSync(releaseGateFixtureSource);
    final config = RefractorConfig.fromYaml(releaseGateConfigYaml);
    final engine = RefractorEngine(
      compiler: DartCompiler(),
      kernelIO: FileKernelIO(),
    );

    final result = await engine.run(
      config: config,
      request: BuildRequest(
        input: sourcePath,
        output: p.join(workDirectory.path, 'out.dill'),
        target: compiler.Target.kernel,
        workDirectory: workDirectory.path,
        projectRootUri: workDirectory.uri,
        projectPackageName: null,
      ),
    );

    final artifact = result.passResults.artifact<RenameArtifact>('rename');
    if (artifact == null) {
      throw StateError('Rename artifact was not produced.');
    }

    return jsonEncode(artifact.toJson());
  }

  String _findDartAotRuntime() {
    final dartExecutable = File(Platform.resolvedExecutable);
    final sdkBin = dartExecutable.parent;
    final sibling = File(p.join(sdkBin.path, 'dartaotruntime'));
    if (sibling.existsSync()) {
      return sibling.path;
    }

    final path = Platform.environment['PATH'];
    if (path != null && path.isNotEmpty) {
      for (final entry in path.split(Platform.isWindows ? ';' : ':')) {
        if (entry.isEmpty) {
          continue;
        }
        final candidate = File(p.join(entry, 'dartaotruntime'));
        if (candidate.existsSync()) {
          return candidate.path;
        }
      }
    }

    throw StateError('Unable to locate dartaotruntime for AOT validation.');
  }
}

class _RunMeasurement {
  const _RunMeasurement({
    required this.outputPath,
    required this.exitCode,
    required this.stdout,
    required this.compileMilliseconds,
    required this.runtimeMilliseconds,
    required this.outputBytes,
  });

  final String outputPath;
  final int exitCode;
  final String stdout;
  final int compileMilliseconds;
  final int runtimeMilliseconds;
  final int outputBytes;
}

class _TimedProcessResult {
  const _TimedProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.runtimeMilliseconds,
  });

  final int exitCode;
  final Object? stdout;
  final Object? stderr;
  final int runtimeMilliseconds;
}
