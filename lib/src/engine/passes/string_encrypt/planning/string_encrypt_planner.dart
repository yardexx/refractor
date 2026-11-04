import 'dart:math';

import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/planning/pass_planner.dart';
import 'package:refractor/src/engine/passes/string_encrypt/planning/planned_string_encryption.dart';
import 'package:refractor/src/engine/passes/string_encrypt/planning/string_encrypt_plan.dart';
import 'package:refractor/src/engine/passes/string_encrypt/selection/string_encrypt_selection.dart';
import 'package:refractor/src/engine/passes/string_encrypt/string_encrypt_codec.dart';

final class StringEncryptPlanner
    implements PassPlanner<StringEncryptSelection, StringEncryptPlan> {
  StringEncryptPlanner({
    required int seed,
  }) : _random = Random(seed);

  final Random _random;

  @override
  StringEncryptPlan plan(
    Component component,
    StringEncryptSelection selection,
  ) {
    final rewrites = <StringLiteral, PlannedStringEncryption>{};

    for (final literal in selection.orderedLiterals) {
      final key = _random.nextInt(0xFFFFFFFF) + 1;
      rewrites[literal] = PlannedStringEncryption(
        targetLiteral: literal,
        key: key,
        encodedBytes: StringEncryptCodec.encodeWithKey(literal.value, key),
      );
    }

    return StringEncryptPlan(
      rewrites: rewrites,
      plannedLiteralCount: rewrites.length,
    );
  }
}
