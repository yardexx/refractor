import 'package:refractor/src/engine/pass/transformation/pass_transform_output.dart';

/// Result of applying the arithmetic-mangle plan.
final class ArithmeticMangleTransformOutput extends PassTransformOutput {
  const ArithmeticMangleTransformOutput({
    required this.mangledCount,
  });

  final int mangledCount;
}
