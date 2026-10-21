import 'package:kernel/ast.dart';

/// The set of functions selected for virtualization (opt-in via annotation).
final class VirtualizeSelection {
  const VirtualizeSelection(this.targets);

  final List<Procedure> targets;
}
