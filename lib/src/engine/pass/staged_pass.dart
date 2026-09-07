import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/pass/pass.dart';
import 'package:refractor/src/engine/pass/pass_result.dart';
import 'package:refractor/src/engine/pass/planning/pass_plan.dart';
import 'package:refractor/src/engine/pass/reporting/pass_artifact.dart';
import 'package:refractor/src/engine/pass/reporting/pass_report.dart';
import 'package:refractor/src/engine/pass/selection/pass_selection.dart';
import 'package:refractor/src/engine/pass/transformation/pass_transform_output.dart';

/// A [Pass] built from the standard staged pipeline:
///
///   select -> plan -> transform -> validate -> report
///
/// A concrete pass fills in each stage as a method; [StagedPass] owns the
/// orchestration, the failure boundary, and result construction, so every
/// staged pass runs the same contract instead of re-implementing it.
///
/// Stages are plain methods. A small pass writes them inline; a large pass
/// delegates each to its own stage class (as `rename` does). [validate] has an
/// empty default, so a pass with no post-mutation invariant simply does not
/// override it — no empty validator class required.
abstract class StagedPass<
  S extends PassSelection,
  P extends PassPlan,
  O extends PassTransformOutput
>
    extends Pass {
  /// Stage 1 — select the nodes this pass is allowed to touch.
  S select(Component component);

  /// Stage 2 — decide the exact mutations as an immutable plan.
  Future<P> plan(Component component, S selection);

  /// Stage 3 — apply the plan to the component.
  Future<O> transform(Component component, P plan);

  /// Stage 4 (optional) — check post-mutation invariants. Defaults to a no-op.
  void validate(Component component, {required P plan, required O output}) {}

  /// Stage 5 — build the report from the selection and transform output.
  PassReport buildReport(S selection, O output);

  /// Stage 5 — build the optional artifact from the transform output.
  PassArtifact? buildArtifact(O output) => null;

  @override
  Future<PassResult> run(Component component) async {
    try {
      final selection = select(component);
      final plan = await this.plan(component, selection);
      final output = await transform(component, plan);
      validate(component, plan: plan, output: output);
      return PassSucceeded(
        artifact: buildArtifact(output),
        report: buildReport(selection, output),
      );
    } on Object catch (error) {
      final exception = error is Exception
          ? error
          : Exception(error.toString());
      return PassFailed(
        error: exception,
        report: PassReport(passName: name, message: error.toString()),
      );
    }
  }
}
