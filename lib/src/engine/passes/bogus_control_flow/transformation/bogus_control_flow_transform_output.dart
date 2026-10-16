import 'package:refractor/src/engine/pass/transformation/pass_transform_output.dart';

/// Result of applying the bogus-control-flow plan.
final class BogusControlFlowTransformOutput extends PassTransformOutput {
  const BogusControlFlowTransformOutput({
    required this.insertedCount,
  });

  final int insertedCount;
}
