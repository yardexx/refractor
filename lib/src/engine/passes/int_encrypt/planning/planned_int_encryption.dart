import 'package:kernel/ast.dart';

final class PlannedIntEncryption {
  const PlannedIntEncryption({
    required this.targetLiteral,
    required this.key,
    required this.encoded,
  });

  final IntLiteral targetLiteral;
  final int key;
  final int encoded;
}
