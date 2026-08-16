import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/transformation/pass_transformer.dart';
import 'package:refractor/src/engine/passes/scoped_kernel_transformer.dart';
import 'package:refractor/src/engine/passes/string_encrypt/planning/string_encrypt_plan.dart';
import 'package:refractor/src/engine/passes/string_encrypt/reporting/string_encryption_record.dart';
import 'package:refractor/src/engine/passes/string_encrypt/runtime/decode_helper_injector.dart';
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

    final setupResult = DecodeHelperInjector(
      scope: _scope,
    ).injectIntoFirstEligibleLibrary(component);
    if (setupResult == null) {
      return const StringEncryptTransformOutput(
        encryptedCount: 0,
        records: [],
      );
    }

    final visitor = _StringEncryptVisitor(
      decodeProcedure: setupResult.decodeProcedure,
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
        libraryUri: _findEnclosingLibrary(node)?.importUri.toString() ?? '',
        enclosingMemberName: _findEnclosingMember(node)?.name.text,
        enclosingMemberKind: _memberKind(_findEnclosingMember(node)),
        fileUri: _findFileUri(node)?.toString(),
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

  Library? _findEnclosingLibrary(TreeNode node) {
    var current = node.parent;
    while (current != null) {
      if (current is Library) return current;
      current = current.parent;
    }
    return null;
  }

  Member? _findEnclosingMember(TreeNode node) {
    var current = node.parent;
    while (current != null) {
      if (current is Member) return current;
      current = current.parent;
    }
    return null;
  }

  Uri? _findFileUri(TreeNode node) {
    final member = _findEnclosingMember(node);
    if (member?.fileUri != null) {
      return member!.fileUri;
    }
    final library = _findEnclosingLibrary(node);
    if (library?.fileUri != null) {
      return library!.fileUri;
    }
    return null;
  }

  String? _memberKind(Member? member) {
    return switch (member) {
      Procedure() => 'procedure',
      Field() => 'field',
      Constructor() => 'constructor',
      _ => null,
    };
  }
}
