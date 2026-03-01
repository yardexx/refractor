import 'dart:io';

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
ProcessResult runProcess(
  String executable,
  List<String> arguments, {
  bool verbose = false,
}) {
  final result = Process.runSync(executable, arguments);

  if (result.exitCode != 0) {
    throw ProcessException(
      executable: executable,
      arguments: arguments,
      exitCode: result.exitCode,
      stderr: result.stderr.toString().trim(),
    );
  }

  return result;
}
