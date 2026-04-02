import 'package:kernel/ast.dart';

final class PlannedStringEncryption {
  const PlannedStringEncryption({
    required this.targetLiteral,
    required this.key,
    required this.encodedBytes,
  });

  final StringLiteral targetLiteral;
  final int key;
  final List<int> encodedBytes;
}
