import 'package:refractor/src/engine/pass/reporting/pass_artifact.dart';
import 'package:refractor/src/engine/passes/virtualize/reporting/virtualization_record.dart';

final class VirtualizeArtifact extends PassArtifact {
  const VirtualizeArtifact({required this.records});

  final List<VirtualizationRecord> records;

  @override
  Map<String, Object?> toJson() => {
    'records': [for (final record in records) record.toJson()],
  };
}
