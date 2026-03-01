import 'package:mason_logger/mason_logger.dart';

/// Base exception for all known errors in the Refractor tool.
///
/// Subclasses correspond to different logical domains of the application
/// and define appropriate standard exit codes.
sealed class RefractorException implements Exception {
  const RefractorException(this.message, {this.cause});

  /// A user-friendly error message.
  final String message;

  /// The underlying cause (another Exception or Error), if any.
  final Object? cause;

  /// The standard exit code to return when this error is caught.
  int get exitCode;

  @override
  String toString() {
    if (cause != null) {
      return '$message\nCaused by: $cause';
    }
    return message;
  }
}

/// Thrown when there is an error parsing or validating configuration files.
class ConfigException extends RefractorException {
  const ConfigException(super.message, {super.cause});

  @override
  int get exitCode => ExitCode.config.code;
}

/// Thrown when the general build process fails (e.g., directory creation,
/// orchestrator logic).
class BuildException extends RefractorException {
  const BuildException(super.message, {super.cause});

  @override
  int get exitCode => ExitCode.software.code; // Generic software error
}

/// Thrown when a specific target compiler (e.g., DartCompiler, FlutterCompiler)
/// fails.
class CompilationException extends RefractorException {
  const CompilationException(super.message, {super.cause});

  @override
  int get exitCode => ExitCode.software.code;
}

/// Thrown when an underlying shell command or process execution fails.
class ProcessRunException extends RefractorException {
  const ProcessRunException(super.message, {super.cause});

  @override
  int get exitCode => ExitCode.software.code;
}

/// Thrown when a file operation fails (e.g., missing input file, inaccessible
/// temp directory).
class FileIoException extends RefractorException {
  const FileIoException(super.message, {super.cause});

  @override
  int get exitCode => ExitCode.ioError.code;
}
