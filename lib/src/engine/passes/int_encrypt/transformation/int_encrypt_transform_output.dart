import 'package:refractor/src/engine/pass/transformation/pass_transform_output.dart';

final class IntEncryptTransformOutput extends PassTransformOutput {
  const IntEncryptTransformOutput({
    required this.encryptedCount,
  });

  final int encryptedCount;
}
