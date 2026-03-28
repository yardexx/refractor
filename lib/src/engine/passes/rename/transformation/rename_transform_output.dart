import 'package:refractor/src/engine/pass/transformation/pass_transform_output.dart';
import 'package:refractor/src/engine/passes/rename/reporting/rename_artifact.dart';

final class RenameTransformOutput extends PassTransformOutput {
  const RenameTransformOutput({
    required this.renamedClasses,
    required this.renamedMembers,
    required this.renamedVariables,
    required this.artifact,
  });

  final int renamedClasses;
  final int renamedMembers;
  final int renamedVariables;
  final RenameArtifact artifact;
}
