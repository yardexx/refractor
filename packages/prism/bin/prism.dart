import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:prism/prism.dart';

/// CLI entry point.
///
/// Usage: `prism verify <artifact> [--map <map.json>] [--policy <policy.yaml>]`
///
/// At least one of `--map` / `--policy` is required; they are independent
/// bands and either can run alone.
///
/// Exit codes: 0 = pass, 1 = a band failed, 64 = usage error.
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addCommand('verify', _verifyParser())
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print usage information.',
    );

  ArgResults top;
  try {
    top = parser.parse(args);
  } on FormatException catch (e) {
    _fail('${e.message}\n\n${_usage(parser)}');
  }

  if (top['help'] as bool || top.command == null) {
    stdout.writeln(_usage(parser));
    return;
  }

  if (top.command!.name == 'verify') {
    exitCode = _runVerify(top.command!);
  }
}

ArgParser _verifyParser() => ArgParser()
  ..addOption('map', abbr: 'm', help: 'Path to the Refractor symbol map JSON.')
  ..addOption('policy', abbr: 'p', help: 'Path to a prism policy YAML.')
  ..addOption(
    'format',
    abbr: 'f',
    allowed: ['text', 'json'],
    defaultsTo: 'text',
    help: 'Output format.',
  )
  ..addOption(
    'min-length',
    defaultsTo: '5',
    help: 'Minimum significant length for a map leak to be high-confidence.',
  )
  ..addOption(
    'fail-on',
    allowed: ['high', 'any', 'none'],
    defaultsTo: 'high',
    help: 'Map-band leak severity that produces a non-zero exit code.',
  );

int _runVerify(ArgResults args) {
  final rest = args.rest;
  if (rest.isEmpty) {
    _fail('verify requires an <artifact> path.');
  }
  final artifactPath = rest.first;
  final mapPath = args['map'] as String?;
  final policyPath = args['policy'] as String?;

  if (mapPath == null && policyPath == null) {
    _fail('verify requires at least one of --map or --policy.');
  }
  if (!File(artifactPath).existsSync()) {
    _fail('artifact not found: $artifactPath');
  }
  if (mapPath != null && !File(mapPath).existsSync()) {
    _fail('symbol map not found: $mapPath');
  }
  if (policyPath != null && !File(policyPath).existsSync()) {
    _fail('policy not found: $policyPath');
  }

  final minLength = int.tryParse(args['min-length'] as String);
  if (minLength == null || minLength < 1) {
    _fail('--min-length must be a positive integer.');
  }

  final failOn = switch (args['fail-on'] as String) {
    'high' => Confidence.high,
    'any' => Confidence.low,
    'none' => null,
    _ => Confidence.high,
  };

  // One read of the artifact, shared by both bands.
  final scanner = BinaryScanner.ofFile(artifactPath);

  VerificationReport? mapReport;
  if (mapPath != null) {
    mapReport = Verifier(minConfidentLength: minLength, failOn: failOn).verify(
      artifactPath: artifactPath,
      symbolMap: SymbolMap.load(mapPath),
      scanner: scanner,
    );
  }

  PolicyReport? policyReport;
  if (policyPath != null) {
    policyReport = const PolicyChecker().check(
      scanner: scanner,
      policy: Policy.load(policyPath),
    );
  }

  final passed = (mapReport?.passed ?? true) && (policyReport?.passed ?? true);

  if (args['format'] == 'json') {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'artifact': artifactPath,
        'passed': passed,
        if (mapReport != null) 'map': mapReport.toJson(),
        if (policyReport != null) 'policy': policyReport.toJson(),
      }),
    );
  } else {
    if (mapReport != null) stdout.write(mapReport.describe());
    if (policyReport != null) stdout.write(policyReport.describe());
    stdout.writeln(passed ? 'VERDICT: pass' : 'VERDICT: FAIL');
  }

  return passed ? 0 : 1;
}

String _usage(ArgParser parser) =>
    'prism — verify a built artifact against a symbol map and/or a policy.\n\n'
    'Usage: prism verify <artifact> [--map <map.json>] [--policy <policy.yaml>]'
    '\n\nOptions:\n${parser.commands['verify']!.usage}';

Never _fail(String message) {
  stderr.writeln(message);
  exit(64);
}
