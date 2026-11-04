import 'package:kernel/ast.dart';

/// The runtime helper procedures the engine injected into the program, keyed
/// by the name each was compiled under.
///
/// Passes resolve their helper through this handle rather than by searching
/// the component for a procedure with that name: the name does not survive a
/// `rename` pass that runs first (the helpers live in a project library, so
/// rename treats them like any other member), and a user procedure could share
/// it. The [Procedure] reference stays valid whatever it is later renamed to.
final class RuntimeHelpers {
  const RuntimeHelpers(this._procedures);

  /// No helpers injected.
  static const RuntimeHelpers none = RuntimeHelpers({});

  final Map<String, Procedure> _procedures;

  /// The injected helper compiled as [name].
  ///
  /// Throws a [StateError] when it was not injected, so a pass that needs it
  /// fails instead of silently rewriting nothing.
  Procedure require(String name) {
    final procedure = _procedures[name];
    if (procedure == null) {
      throw StateError('Runtime helper "$name" was not injected.');
    }
    return procedure;
  }
}
