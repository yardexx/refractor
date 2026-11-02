import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel/runtime_helpers.dart';
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
    required RuntimeHelpers helpers,
  }) : _scope = scope,
       _helpers = helpers;

  final ObfuscationScope _scope;
  final RuntimeHelpers _helpers;

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

    final decodeProcedure = _helpers.require(decodeRuntimeHelperName);

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
}

final class _StringEncryptVisitor extends ScopedKernelTransformer {
  _StringEncryptVisitor({
    required this.decodeProcedure,
    required this.plan,
    required super.scope,
  });

  final Procedure decodeProcedure;
  final StringEncryptPlan plan;

  /// The element type of the decoder's `bytes` parameter (`int`).
  late final DartType _bytesElementType =
      (decodeProcedure.function.positionalParameters.first.type
              as InterfaceType)
          .typeArguments
          .single;

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
          // Typed to match `refractorDecode(List<int> bytes, ...)`. An untyped
          // literal is a `List<dynamic>`: a direct call never checks it, but a
          // call routed through `Function.apply` (call_indirection) does and
          // throws a TypeError.
          typeArgument: _bytesElementType,
        ),
        IntLiteral(rewrite.key),
      ]),
    );
  }
}
