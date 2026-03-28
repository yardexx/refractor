import 'package:refractor/src/engine/pass/reporting/pass_artifact.dart';
import 'package:refractor/src/engine/passes/rename/reporting/rename_mapping.dart';

final class RenameArtifact extends PassArtifact {
  const RenameArtifact({
    required this.mapping,
  });

  final RenameMapping mapping;

  @override
  Map<String, Object?> toJson() => {
    'symbol_map': mapping.toJson(),
  };
}
