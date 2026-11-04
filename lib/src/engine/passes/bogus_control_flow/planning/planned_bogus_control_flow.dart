import 'package:kernel/ast.dart';

/// One planned bogus branch: the [function] to wrap, and the [guardVariable]
/// (an in-scope non-nullable int parameter) its always-true guard reads.
final class PlannedBogusControlFlow {
  const PlannedBogusControlFlow({
    required this.function,
    required this.guardVariable,
  });

  final FunctionNode function;
  final VariableDeclaration guardVariable;
}
