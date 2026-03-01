import 'package:glob/glob.dart';

/// Configuration options for the obfuscation engine.
class PassOptions {
  const PassOptions({
    this.excludeLibraryUriPatterns = const [],
    this.preserveMain = true,
    this.stringExcludePatterns = const [],
    this.verbose = false,
  });

  /// URI/path regex patterns for libraries to skip entirely.
  final List<Glob> excludeLibraryUriPatterns;

  /// If true, the top-level `main` procedure is not renamed.
  final bool preserveMain;

  /// Regex patterns for string literals that should not be encrypted.
  final List<RegExp> stringExcludePatterns;

  /// If true, enable verbose logging.
  final bool verbose;
}
