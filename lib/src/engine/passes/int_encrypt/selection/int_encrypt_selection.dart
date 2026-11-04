import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/selection/pass_selection.dart';

final class IntEncryptSelection extends PassSelection {
  IntEncryptSelection({
    required List<IntLiteral> orderedLiterals,
  }) : _orderedLiterals = List.unmodifiable(orderedLiterals),
       _intLiterals = Set.identity()..addAll(orderedLiterals);

  final List<IntLiteral> _orderedLiterals;
  final Set<IntLiteral> _intLiterals;

  int get selectedLiteralCount => _intLiterals.length;
  List<IntLiteral> get orderedLiterals => _orderedLiterals;

  bool contains(IntLiteral literal) => _intLiterals.contains(literal);
}
