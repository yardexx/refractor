import 'package:refractor/src/engine/pass/transformation/pass_transform_output.dart';

final class CallIndirectionTransformOutput extends PassTransformOutput {
  const CallIndirectionTransformOutput({
    required this.indirectedCount,
  });

  final int indirectedCount;
}
