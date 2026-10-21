/// Annotation namespace for Refractor-owned source markers.
///
/// Prefer using the namespaced constructor form at call sites:
///
/// ```dart
/// @Refractor.keep()
/// class PublicApi {}
/// ```
sealed class Refractor {
  /// Marks a declaration to be preserved by supported Refractor passes.
  ///
  /// In the first shipped release this means the declaration should be kept by
  /// Refractor's rename pass.
  const factory Refractor.keep() = RefractorKeep;

  /// Marks a function to be virtualized (compiled to bytecode run by an
  /// injected interpreter) by Refractor's virtualization pass.
  ///
  /// Opt-in and surgical: only annotated, eligible functions are virtualized.
  /// Virtualization is a high-cost transform intended for a small set of
  /// cold, security-critical functions (e.g. license / anti-tamper checks).
  const factory Refractor.virtualize() = RefractorVirtualize;
}

/// Concrete keep marker used by [Refractor.keep].
final class RefractorKeep implements Refractor {
  const RefractorKeep();
}

/// Concrete virtualize marker used by [Refractor.virtualize].
final class RefractorVirtualize implements Refractor {
  const RefractorVirtualize();
}
