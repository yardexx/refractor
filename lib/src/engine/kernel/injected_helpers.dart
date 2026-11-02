import 'package:kernel/ast.dart';

/// The runtime helper procedures injected into each [Component], keyed by the
/// name they had at injection.
///
/// Passes look helpers up here by reference rather than by their current name:
/// a `rename` pass running before the consuming pass renames the injected
/// helpers along with the rest of the program, so a lookup by name would find
/// nothing.
abstract final class InjectedHelpers {
  static final Expando<Map<String, Procedure>> _byComponent = Expando();

  /// Records [helpers] as injected into [component].
  static void record(Component component, Map<String, Procedure> helpers) {
    (_byComponent[component] ??= <String, Procedure>{}).addAll(helpers);
  }

  /// The helper injected into [component] as [name], or null when none was
  /// injected (e.g. no eligible library).
  ///
  /// Falls back to a top-level procedure currently named [name], for
  /// components whose helper was added without going through injection.
  static Procedure? resolve(Component component, String name) {
    final recorded = _byComponent[component]?[name];
    if (recorded != null) return recorded;
    for (final library in component.libraries) {
      for (final procedure in library.procedures) {
        if (procedure.name.text == name) return procedure;
      }
    }
    return null;
  }
}
