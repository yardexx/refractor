/// The fixed vocabulary of keep mechanisms Refractor supports.
///
/// This is framework-owned, not pass-owned: a pass declares *which* of these
/// it honors (via `PassDefinition.keepSources`), and the keep resolver applies
/// exactly those. The resolver never branches on pass identity — only on this
/// set — which is how the keep system stays decoupled from specific passes.
enum KeepSource {
  /// Glob excludes: the global `refractor.exclude` list plus the pass's own
  /// `exclude` list. Keeps whole libraries.
  excludes,

  /// `@Refractor.keep()` annotations on classes and members.
  annotations,

  /// The program entry point (`main`).
  entryPoint,
}
