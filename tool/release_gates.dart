import 'dart:io';

import 'package:args/args.dart';

import 'release_gates/release_gates.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'output',
      help: 'Machine-readable release gate report path.',
      defaultsTo: 'build/release_gates/report.json',
    )
    ..addOption(
      'target',
      help: 'Limit validation to one runtime target.',
      allowed: [for (final target in ReleaseGateTarget.values) target.value],
    )
    ..addFlag(
      'include-blocked',
      help: 'Include gates blocked by unimplemented dependent features.',
      defaultsTo: true,
    );

  final results = parser.parse(arguments);
  final selectedTarget = results.option('target');
  final targets = selectedTarget == null
      ? ReleaseGateTarget.values
      : [ReleaseGateTarget.parse(selectedTarget)];
  final includeBlocked = results.flag('include-blocked');
  final outputPath = results.option('output')!;

  const runner = ReleaseGateRunner(probe: RealReleaseGateProbe());
  final report = await runner.run(
    targets: targets,
    includeBlocked: includeBlocked,
  );

  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(report.toJsonString());

  stdout
    ..writeln('Release gate status: ${report.status.name}')
    ..writeln('Report: ${outputFile.path}');
  for (final gate in report.globalGates) {
    stdout.writeln('- ${gate.status.name}: ${gate.name}');
  }
  for (final target in report.targets) {
    stdout.writeln('- target ${target.target.value}');
    for (final gate in target.gates) {
      stdout.writeln('  - ${gate.status.name}: ${gate.name}');
    }
    for (final budget in target.budgets) {
      stdout.writeln(
        '  - budget ${budget.id}: '
        '${budget.baseline} -> ${budget.candidate} '
        '${budget.unit} (delta ${budget.delta})',
      );
    }
  }

  if (report.hasFailures) {
    exitCode = 1;
  }
}
