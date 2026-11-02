import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/pass/planning/pass_plan.dart';
import 'package:refractor/src/engine/pass/transformation/pass_transform_output.dart';

abstract interface class PassTransformer<
  P extends PassPlan,
  O extends PassTransformOutput
> {
  O apply(Component component, P plan);
}
