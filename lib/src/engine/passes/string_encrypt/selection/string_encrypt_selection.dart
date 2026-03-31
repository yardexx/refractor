import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/selection/pass_selection.dart';

final class StringEncryptSelection extends PassSelection {
  StringEncryptSelection({
    required List<StringLiteral> orderedLiterals,
  }) : _orderedLiterals = List.unmodifiable(orderedLiterals),
       _stringLiterals = Set.unmodifiable(orderedLiterals);

  final List<StringLiteral> _orderedLiterals;
  final Set<StringLiteral> _stringLiterals;

  int get selectedLiteralCount => _stringLiterals.length;
  List<StringLiteral> get orderedLiterals => _orderedLiterals;

  bool contains(StringLiteral literal) => _stringLiterals.contains(literal);
}
