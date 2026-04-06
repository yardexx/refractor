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
}

/// Concrete keep marker used by [Refractor.keep].
final class RefractorKeep implements Refractor {
  const RefractorKeep();
}
