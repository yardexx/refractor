import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart' show ExitCode;
import 'package:refractor/src/cli/commands/refractor_command.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:refractor/src/symbolication/symbol_map.dart';
import 'package:refractor/src/symbolication/symbolicator.dart';

/// Reverses an obfuscated stack trace back to original identifiers using a
/// symbol map produced by a build.
///
/// Usage: `refractor symbolicate [trace-file] [--symbol-map path]`
///
/// The trace is read from [trace-file] if given, otherwise from stdin. The
/// symbolicated trace is written to stdout.
class SymbolicateCommand extends RefractorCommand {
  SymbolicateCommand({super.logger}) {
    argParser.addOption(
      'symbol-map',
      abbr: 'm',
      help:
          'Path to the symbol map JSON. Relative paths resolve under the '
          'build directory, matching where `build` writes it.',
      defaultsTo: 'symbol_map.json',
    );
  }

  @override
  String get name => 'symbolicate';

  @override
  String get description =>
      'Reverse an obfuscated stack trace using a symbol map.';

  @override
  Future<int> run() async {
    final mapPath = workspace.auxiliaryOutputPath(
      argResults.option('symbol-map')!,
    );
    final mapFile = File(mapPath);
    if (!mapFile.existsSync()) {
      throw ConfigException('Symbol map not found: $mapPath');
    }

    final SymbolMap map;
    try {
      map = SymbolMap.fromJson(
        jsonDecode(mapFile.readAsStringSync()) as Map<String, dynamic>,
      );
    } on ConfigException {
      rethrow;
    } on Object catch (e) {
      throw ConfigException('Invalid symbol map at $mapPath.', cause: e);
    }

    final trace = _readTrace();
    logger.info(Symbolicator(map).symbolicateTrace(trace));
    return ExitCode.success.code;
  }

  /// The obfuscated trace: the first positional argument as a file path, or
  /// stdin when no path is given.
  String _readTrace() {
    final rest = argResults.rest;
    if (rest.isNotEmpty) {
      final traceFile = File(rest.first);
      if (!traceFile.existsSync()) {
        throw ConfigException('Trace file not found: ${rest.first}');
      }
      return traceFile.readAsStringSync();
    }

    final buffer = StringBuffer();
    String? line;
    while ((line = stdin.readLineSync()) != null) {
      buffer.writeln(line);
    }
    return buffer.toString();
  }
}
