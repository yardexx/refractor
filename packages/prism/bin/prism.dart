import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:prism/prism.dart';

/// CLI entry point.
///
/// Usage: `prism verify <artifact> --map <symbol_map.json> [options]`
///
/// Exit codes: 0 = pass, 1 = leaks found (per `--fail-on`), 64 = usage error.
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
    help: 'Minimum significant length for a leak to be high-confidence.',
  )
  ..addOption(
    'fail-on',
    allowed: ['high', 'any', 'none'],
    defaultsTo: 'high',
    help: 'Severity that produces a non-zero exit code.',
  );

int _runVerify(ArgResults args) {
  final rest = args.rest;
  if (rest.isEmpty) {
    _fail('verify requires an <artifact> path.');
  }
  final artifactPath = rest.first;
  final mapPath = args['map'] as String?;
  if (mapPath == null) {
    _fail('verify requires --map <symbol_map.json>.');
  }

  if (!File(artifactPath).existsSync()) {
    _fail('artifact not found: $artifactPath');
  }
  if (!File(mapPath).existsSync()) {
    _fail('symbol map not found: $mapPath');
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

  final report = Verifier(
    minConfidentLength: minLength,
    failOn: failOn,
  ).verify(
    artifactPath: artifactPath,
    symbolMap: SymbolMap.load(mapPath),
  );

  if (args['format'] == 'json') {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report.toJson()));
  } else {
    stdout.write(report.describe());
  }
  return report.exitCode;
}

String _usage(ArgParser parser) =>
    'prism — verify a built artifact against a Refractor symbol map.\n\n'
    'Usage: prism verify <artifact> --map <symbol_map.json> [options]\n\n'
    'Options:\n${parser.commands['verify']!.usage}';

Never _fail(String message) {
  stderr.writeln(message);
  exit(64);
}
