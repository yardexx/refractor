import 'package:kernel/ast.dart';
import 'package:kernel/target/targets.dart';
import 'package:kernel/verifier.dart';

/// Runs the vendored kernel verifier over the transformed component to confirm
/// the synthesized interpreter(s) and rewritten bodies are well-formed. This is
/// the structural half of the E6 gate (the differential-equivalence half is a
/// unit-test harness over the lowerer + reference interpreter).
final class VirtualizeValidator {
  const VirtualizeValidator();

  /// Returns null on success, or an error message on failure.
  String? verify(Component component) {
    try {
      verifyComponent(
        NoneTarget(const TargetFlags()),
        VerificationStage.afterModularTransformations,
        component,
        skipPlatform: true,
        librarySkipFilter: (library) => library.importUri.isScheme('dart'),
      );
      return null;
    } on Object catch (error) {
      return error.toString();
    }
  }
}
