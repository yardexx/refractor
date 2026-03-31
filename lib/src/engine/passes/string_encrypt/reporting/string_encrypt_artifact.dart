import 'package:refractor/src/engine/pass/reporting/pass_artifact.dart';
import 'package:refractor/src/engine/passes/string_encrypt/reporting/string_encryption_record.dart';

final class StringEncryptArtifact extends PassArtifact {
  const StringEncryptArtifact({
    required this.records,
  });

  final List<StringEncryptionRecord> records;

  @override
  Map<String, Object?> toJson() => {
    'records': [
      for (final record in records) record.toJson(),
    ],
  };
}
