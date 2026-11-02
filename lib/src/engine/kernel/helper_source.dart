/// A runtime helper authored as plain Dart, to be compiled and injected into
/// the program being obfuscated by `SourceHelperInjector`.
///
/// A pass declares the helpers it needs via `PassDefinition.runtimeHelpers`;
/// the engine injects them once, before passes run, and each pass resolves the
/// reparented procedures through `InjectedHelpers`.
class HelperSource {
  const HelperSource({
    required this.source,
    required this.procedureNames,
  });

  /// The Dart source of the helper library. It must have a `main` so
  /// `dart compile kernel` accepts it as an entrypoint; the helper library
  /// (and its `main`) is dropped after the named procedures are reparented.
  final String source;

  /// The names of the top-level procedures to pull out of the compiled helper
  /// and reparent into the program. Other declarations are dropped.
  final Set<String> procedureNames;
}
