import 'package:refractor/src/engine/pass/transformation/pass_transform_output.dart';

/// Result of applying the dead-code plan.
final class DeadCodeTransformOutput extends PassTransformOutput {
  const DeadCodeTransformOutput({
    required this.insertedCount,
  });

  final int insertedCount;
}
