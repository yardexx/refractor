import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/planning/pass_plan.dart';
import 'package:refractor/src/engine/passes/string_encrypt/planning/planned_string_encryption.dart';

final class StringEncryptPlan extends PassPlan {
  StringEncryptPlan({
    required Map<StringLiteral, PlannedStringEncryption> rewrites,
    required this.plannedLiteralCount,
  }) : _rewrites = Map.unmodifiable(rewrites);

  final Map<StringLiteral, PlannedStringEncryption> _rewrites;
  final int plannedLiteralCount;

  Map<StringLiteral, PlannedStringEncryption> get rewrites => _rewrites;

  PlannedStringEncryption? rewriteFor(StringLiteral literal) {
    return _rewrites[literal];
  }
}
