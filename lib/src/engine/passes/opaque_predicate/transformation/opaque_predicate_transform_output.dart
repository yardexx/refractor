import 'package:refractor/src/engine/pass/transformation/pass_transform_output.dart';

/// Result of applying the opaque-predicate plan.
final class OpaquePredicateTransformOutput extends PassTransformOutput {
  const OpaquePredicateTransformOutput({
    required this.strengthenedCount,
  });

  final int strengthenedCount;
}
