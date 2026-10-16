import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/planning/pass_plan.dart';
import 'package:refractor/src/engine/passes/int_encrypt/planning/planned_int_encryption.dart';

final class IntEncryptPlan extends PassPlan {
  IntEncryptPlan({
    required Map<IntLiteral, PlannedIntEncryption> rewrites,
    required this.plannedLiteralCount,
  }) : _rewrites = Map.identity()..addAll(rewrites);

  final Map<IntLiteral, PlannedIntEncryption> _rewrites;
  final int plannedLiteralCount;

  Iterable<PlannedIntEncryption> get rewrites => _rewrites.values;

  PlannedIntEncryption? rewriteFor(IntLiteral literal) => _rewrites[literal];
}
