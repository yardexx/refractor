import 'dart:math';

import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/planning/pass_planner.dart';
import 'package:refractor/src/engine/passes/int_encrypt/planning/int_encrypt_plan.dart';
import 'package:refractor/src/engine/passes/int_encrypt/planning/planned_int_encryption.dart';
import 'package:refractor/src/engine/passes/int_encrypt/selection/int_encrypt_selection.dart';

final class IntEncryptPlanner
    implements PassPlanner<IntEncryptSelection, IntEncryptPlan> {
  IntEncryptPlanner({
    required int seed,
  }) : _random = Random(seed);

  final Random _random;

  @override
  Future<IntEncryptPlan> plan(
    Component component,
    IntEncryptSelection selection,
  ) async {
    final rewrites = Map<IntLiteral, PlannedIntEncryption>.identity();

    for (final literal in selection.orderedLiterals) {
      final key = _nextKey();
      rewrites[literal] = PlannedIntEncryption(
        targetLiteral: literal,
        key: key,
        encoded: literal.value ^ key,
      );
    }

    return IntEncryptPlan(
      rewrites: rewrites,
      plannedLiteralCount: rewrites.length,
    );
  }

  /// A full-width 64-bit key, so high bits of large literals are masked too.
  /// Never zero (that would leave the value in the clear).
  int _nextKey() {
    final high = _random.nextInt(1 << 32);
    final low = _random.nextInt(1 << 32);
    final key = (high << 32) ^ low;
    return key == 0 ? 1 : key;
  }
}
