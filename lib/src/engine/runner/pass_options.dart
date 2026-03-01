/// Configuration options for the obfuscation engine.
class PassOptions {
  const PassOptions({
    this.packageFilter,
    this.preserveMain = true,
    this.excludeNames = const {},
    this.excludePatterns = const [],
    this.excludeAnnotations = const {},
    this.verbose = false,
  });

  /// Only obfuscate libraries whose URI contains this string.
  /// If null, obfuscates all non-SDK, non-package libraries.
  final String? packageFilter;

  /// If true, the top-level `main` procedure is not renamed.
  final bool preserveMain;

  /// List of exact member names to exclude from renaming.
  final Set<String> excludeNames;

  /// Regex patterns — any name matching is excluded from renaming.
  final List<RegExp> excludePatterns;

  /// Annotation class names — members annotated with these are excluded.
  final Set<String> excludeAnnotations;

  /// If true, enable verbose logging.
  final bool verbose;
}
