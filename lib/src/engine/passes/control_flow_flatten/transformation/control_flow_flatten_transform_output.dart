import 'package:refractor/src/engine/pass/transformation/pass_transform_output.dart';

/// Result of applying the control-flow-flatten plan.
final class ControlFlowFlattenTransformOutput extends PassTransformOutput {
  const ControlFlowFlattenTransformOutput({
    required this.flattenedCount,
  });

  final int flattenedCount;
}
