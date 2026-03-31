import 'package:refractor/src/engine/passes/string_encrypt/planning/planned_string_encryption.dart';

final class StringEncryptionRecord {
  const StringEncryptionRecord({
    required this.plaintext,
    required this.encodedBytes,
    required this.key,
    required this.libraryUri,
    required this.enclosingMemberName,
    required this.enclosingMemberKind,
    required this.fileUri,
  });

  factory StringEncryptionRecord.fromPlanned({
    required PlannedStringEncryption planned,
    required String libraryUri,
    String? enclosingMemberName,
    String? enclosingMemberKind,
    String? fileUri,
  }) {
    return StringEncryptionRecord(
      plaintext: planned.targetLiteral.value,
      encodedBytes: planned.encodedBytes,
      key: planned.key,
      libraryUri: libraryUri,
      enclosingMemberName: enclosingMemberName,
      enclosingMemberKind: enclosingMemberKind,
      fileUri: fileUri,
    );
  }

  final String plaintext;
  final List<int> encodedBytes;
  final int key;
  final String libraryUri;
  final String? enclosingMemberName;
  final String? enclosingMemberKind;
  final String? fileUri;

  Map<String, Object?> toJson() => {
    'plaintext': plaintext,
    'encoded_bytes': encodedBytes,
    'key': key,
    'library_uri': libraryUri,
    'enclosing_member_name': enclosingMemberName,
    'enclosing_member_kind': enclosingMemberKind,
    'file_uri': fileUri,
  };
}
