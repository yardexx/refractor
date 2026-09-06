import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

/// Exception thrown when a subprocess exits with a non-zero exit code.
class ProcessException implements Exception {
  ProcessException({
    required this.executable,
    required this.arguments,
    required this.exitCode,
    required this.stderr,
  });
  final String executable;
  final List<String> arguments;
  final int exitCode;
  final String stderr;

  @override
  String toString() {
    final cmd = '$executable ${arguments.join(' ')}';
    return 'Command failed (exit $exitCode): $cmd\n$stderr';
  }
}

/// Runs a subprocess synchronously, throwing [ProcessException] on failure.
///
/// When [logger] is supplied, the command and its output are logged at the
/// verbose ([Logger.detail]) level, so they surface only when verbose logging
/// is enabled.
ProcessResult runProcess(
  String executable,
  List<String> arguments, {
  Logger? logger,
}) {
  logger?.detail('\$ $executable ${arguments.join(' ')}');

  final result = Process.runSync(executable, arguments);

  if (result.exitCode != 0) {
    throw ProcessException(
      executable: executable,
      arguments: arguments,
      exitCode: result.exitCode,
      stderr: result.stderr.toString().trim(),
    );
  }

  final stdoutText = result.stdout.toString().trim();
  if (stdoutText.isNotEmpty) logger?.detail(stdoutText);
  final stderrText = result.stderr.toString().trim();
  if (stderrText.isNotEmpty) logger?.detail(stderrText);

  return result;
}
