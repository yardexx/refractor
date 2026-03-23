import 'package:refractor/src/engine/pass/pass_artifact.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_mapping.dart';

final class RenameArtifact extends PassArtifact {
  const RenameArtifact({
    required this.mapping,
  });

  final RenameMapping mapping;
}
