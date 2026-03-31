import 'package:refractor/src/engine/pass/transformation/pass_transform_output.dart';
import 'package:refractor/src/engine/passes/string_encrypt/reporting/string_encryption_record.dart';

final class StringEncryptTransformOutput extends PassTransformOutput {
  const StringEncryptTransformOutput({
    required this.encryptedCount,
    required this.records,
  });

  final int encryptedCount;
  final List<StringEncryptionRecord> records;
}
