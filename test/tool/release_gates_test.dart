import 'dart:io';

import 'package:test/test.dart';

import '../../tool/release_gates/release_gates.dart';

void main() {
  group('ReleaseGateReport', () {
    test('serializes status and budget deltas', () {
      final report = ReleaseGateReport(
        generatedAt: DateTime.utc(2026, 4, 15),
        dartVersion: '3.11.3',
        hostOs: 'macos',
        fixtureName: 'fixture',
        globalGates: const [
          HardGateResult(
            id: 'artifact_ownership',
            name: 'Artifact Ownership',
            status: ReleaseGateStatus.passed,
            message: 'ok',
          ),
        ],
        targets: const [
          TargetValidationResult(
            target: ReleaseGateTarget.exe,
            gates: [
              HardGateResult(
                id: 'correctness_exe',
                name: 'Correctness On exe',
                status: ReleaseGateStatus.passed,
                message: 'matched',
              ),
            ],
            budgets: [
              BudgetMeasurement(
                id: 'compile_time_exe',
                name: 'Compile Time',
                unit: 'milliseconds',
                baseline: 10,
                candidate: 14,
              ),
            ],
          ),
        ],
      );

      expect(report.status, ReleaseGateStatus.passed);
      expect(report.isFullSignoffReady, isTrue);
      expect(report.toJson(), {
        'schema': 'refractor.release_gates/v1',
        'generated_at': '2026-04-15T00:00:00.000Z',
        'status': 'passed',
        'dart_version': '3.11.3',
        'host_os': 'macos',
        'fixture_name': 'fixture',
        'global_gates': [
          {
            'id': 'artifact_ownership',
            'name': 'Artifact Ownership',
            'status': 'passed',
            'message': 'ok',
          },
        ],
        'targets': [
          {
            'target': 'exe',
            'gates': [
              {
                'id': 'correctness_exe',
                'name': 'Correctness On exe',
                'status': 'passed',
                'message': 'matched',
              },
            ],
            'budgets': [
              {
                'id': 'compile_time_exe',
                'name': 'Compile Time',
                'unit': 'milliseconds',
                'baseline': 10,
                'candidate': 14,
                'delta': 4,
              },
            ],
          },
        ],
      });
    });

    test('aggregates failed before blocked before passed', () {
      final blockedReport = _reportWithGates([
        const HardGateResult(
          id: 'dry_run_workflow',
          name: 'Dry Run',
          status: ReleaseGateStatus.blocked,
          message: 'blocked',
        ),
      ]);
      final failedReport = _reportWithGates([
        const HardGateResult(
          id: 'dry_run_workflow',
          name: 'Dry Run',
          status: ReleaseGateStatus.blocked,
          message: 'blocked',
        ),
        const HardGateResult(
          id: 'correctness_exe',
          name: 'Correctness',
          status: ReleaseGateStatus.failed,
          message: 'failed',
        ),
      ]);

      expect(blockedReport.status, ReleaseGateStatus.blocked);
      expect(blockedReport.hasFailures, isFalse);
      expect(blockedReport.isFullSignoffReady, isFalse);
      expect(failedReport.status, ReleaseGateStatus.failed);
      expect(failedReport.hasFailures, isTrue);
    });
  });

  group('ReleaseGateRunner', () {
    test('requires all mandatory runtime targets for full signoff', () async {
      final report =
          await const ReleaseGateRunner(
            probe: _FakeProbe(),
            clock: _FixedClock(),
          ).run(
            targets: [ReleaseGateTarget.exe],
            includeBlocked: false,
            workDirectory: Directory.systemTemp.createTempSync(
              'release_gate_test_',
            ),
          );

      final requiredTargetGate = report.globalGates.singleWhere(
        (gate) => gate.id == 'required_targets',
      );

      expect(requiredTargetGate.status, ReleaseGateStatus.blocked);
      expect(requiredTargetGate.evidence['missing'], ['jit', 'aot']);
      expect(report.status, ReleaseGateStatus.blocked);
    });

    test('records failed correctness from the probe', () async {
      final report =
          await const ReleaseGateRunner(
            probe: _FakeProbe(failedTargets: {ReleaseGateTarget.jit}),
            clock: _FixedClock(),
          ).run(
            includeBlocked: false,
            workDirectory: Directory.systemTemp.createTempSync(
              'release_gate_test_',
            ),
          );

      final jitGate = report.hardGates.singleWhere(
        (gate) => gate.id == 'correctness_jit',
      );

      expect(jitGate.status, ReleaseGateStatus.failed);
      expect(report.status, ReleaseGateStatus.failed);
    });

    test('budget deltas do not fail release gates', () async {
      final report =
          await const ReleaseGateRunner(
            probe: _FakeProbe(candidateBudget: 9999),
            clock: _FixedClock(),
          ).run(
            includeBlocked: false,
            workDirectory: Directory.systemTemp.createTempSync(
              'release_gate_test_',
            ),
          );

      expect(report.status, ReleaseGateStatus.passed);
      expect(
        report.targets.first.budgets
            .singleWhere(
              (budget) => budget.id == 'compile_time_exe',
            )
            .delta,
        9989,
      );
    });

    test('reports dry-run and symbolication dependencies as blocked', () async {
      final report =
          await const ReleaseGateRunner(
            probe: _FakeProbe(),
            clock: _FixedClock(),
          ).run(
            workDirectory: Directory.systemTemp.createTempSync(
              'release_gate_test_',
            ),
          );

      expect(
        report.globalGates
            .where((gate) => gate.status == ReleaseGateStatus.blocked)
            .map((gate) => gate.id),
        containsAll(['dry_run_workflow', 'symbolication_workflow']),
      );
      expect(report.status, ReleaseGateStatus.blocked);
    });
  });
}

ReleaseGateReport _reportWithGates(List<HardGateResult> gates) {
  return ReleaseGateReport(
    generatedAt: DateTime.utc(2026, 4, 15),
    dartVersion: '3.11.3',
    hostOs: 'macos',
    fixtureName: 'fixture',
    targets: const [],
    globalGates: gates,
  );
}

class _FakeProbe implements ReleaseGateProbe {
  const _FakeProbe({
    this.failedTargets = const {},
    this.candidateBudget = 11,
  });

  final Set<ReleaseGateTarget> failedTargets;
  final int candidateBudget;

  @override
  Future<HardGateResult> validateArtifactGate(Directory workDirectory) async {
    return const HardGateResult(
      id: 'artifact_ownership',
      name: 'Artifact Ownership',
      status: ReleaseGateStatus.passed,
      message: 'generic artifact path validated',
      evidence: {'artifact_path': 'build/release_gates/artifacts.json'},
    );
  }

  @override
  Future<HardGateResult> validateDeterminismGate(
    Directory workDirectory,
  ) async {
    return const HardGateResult(
      id: 'fixed_seed_determinism',
      name: 'Fixed-Seed Rename Determinism',
      status: ReleaseGateStatus.passed,
      message: 'deterministic',
    );
  }

  @override
  Future<TargetValidationResult> validateTarget(
    ReleaseGateTarget target,
    Directory workDirectory,
  ) async {
    final failed = failedTargets.contains(target);
    return TargetValidationResult(
      target: target,
      gates: [
        HardGateResult(
          id: 'correctness_${target.value}',
          name: 'Correctness On ${target.value}',
          status: failed ? ReleaseGateStatus.failed : ReleaseGateStatus.passed,
          message: failed ? 'mismatch' : 'matched',
        ),
      ],
      budgets: [
        BudgetMeasurement(
          id: 'compile_time_${target.value}',
          name: 'Compile Time',
          unit: 'milliseconds',
          baseline: 10,
          candidate: candidateBudget,
        ),
      ],
    );
  }
}

class _FixedClock implements Clock {
  const _FixedClock();

  @override
  DateTime now() => DateTime.utc(2026, 4, 15);
}
