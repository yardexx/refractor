import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/pass/planning/pass_plan.dart';
import 'package:refractor/src/engine/pass/transformation/pass_transform_output.dart';

abstract interface class PassValidator<
  P extends PassPlan,
  O extends PassTransformOutput
> {
  void validate(
    Component component, {
    required P plan,
    required O output,
  });
}
