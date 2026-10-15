import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/location/enclosing.dart';
import 'package:refractor/src/engine/kernel_toolkit/relations/member_model.dart';
import 'package:refractor/src/engine/kernel_toolkit/traversal/scoped_transformer.dart';
import 'package:refractor/src/engine/pass/transformation/pass_transformer.dart';
import 'package:refractor/src/engine/passes/string_encrypt/planning/string_encrypt_plan.dart';
import 'package:refractor/src/engine/passes/string_encrypt/reporting/string_encryption_record.dart';
import 'package:refractor/src/engine/passes/string_encrypt/runtime/decode_runtime.dart';
import 'package:refractor/src/engine/passes/string_encrypt/transformation/string_encrypt_transform_output.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

class StringEncryptTransformer
    implements
        PassTransformer<StringEncryptPlan, StringEncryptTransformOutput> {
  StringEncryptTransformer({
    required ObfuscationScope scope,
  }) : _scope = scope;

  final ObfuscationScope _scope;

  @override
  Future<StringEncryptTransformOutput> apply(
    Component component,
    StringEncryptPlan plan,
  ) async {
    if (plan.rewrites.isEmpty) {
      return const StringEncryptTransformOutput(
        encryptedCount: 0,
        records: [],
      );
    }

    final decodeProcedure = _resolveDecodeProcedure(component);
    if (decodeProcedure == null) {
      return const StringEncryptTransformOutput(
        encryptedCount: 0,
        records: [],
      );
    }

    final visitor = _StringEncryptVisitor(
      decodeProcedure: decodeProcedure,
      scope: _scope,
      plan: plan,
    );
    component.transformChildren(visitor);
    return StringEncryptTransformOutput(
      encryptedCount: visitor.encryptedCount,
      records: List.unmodifiable(visitor.records),
    );
  }

  /// Finds the decode helper the engine injected into the program. Returns null
  /// when it is absent (e.g. no eligible library), in which case no literal is
  /// rewritten.
  Procedure? _resolveDecodeProcedure(Component component) {
    for (final library in component.libraries) {
      for (final procedure in library.procedures) {
        if (procedure.name.text == decodeRuntimeHelperName) return procedure;
      }
    }
    return null;
  }
}

final class _StringEncryptVisitor extends ScopedKernelTransformer {
  _StringEncryptVisitor({
    required this.decodeProcedure,
    required this.plan,
    required super.scope,
  });

  final Procedure decodeProcedure;
  final StringEncryptPlan plan;

  int encryptedCount = 0;
  final List<StringEncryptionRecord> records = [];

  @override
  TreeNode visitStringLiteral(StringLiteral node) {
    final rewrite = plan.rewriteFor(node);
    if (rewrite == null) {
      return node;
    }

    encryptedCount++;
    records.add(
      StringEncryptionRecord.fromPlanned(
        planned: rewrite,
        libraryUri: Enclosing.library(node)?.importUri.toString() ?? '',
        enclosingMemberName: Enclosing.member(node)?.name.text,
        enclosingMemberKind: MemberModel.kindLabel(Enclosing.member(node)),
        fileUri: Enclosing.fileUri(node)?.toString(),
      ),
    );

    return StaticInvocation(
      decodeProcedure,
      Arguments([
        ListLiteral(
          rewrite.encodedBytes
              .map((byte) => IntLiteral(byte) as Expression)
              .toList(),
        ),
        IntLiteral(rewrite.key),
      ]),
    );
  }
}
