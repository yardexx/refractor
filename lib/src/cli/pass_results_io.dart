import 'dart:convert';
import 'dart:io';

import 'package:refractor/src/engine/pass.dart';

extension PassResultsIo on PassResults {
  bool get hasArtifacts => artifacts.isNotEmpty;

  Map<String, Object?> toArtifactsJson() => {
    'passes': {
      for (final entry in artifacts.entries) entry.key: entry.value.toJson(),
    },
  };

  String toArtifactsJsonString() {
    return const JsonEncoder.withIndent('  ').convert(toArtifactsJson());
  }

  void writeArtifactsToPath(String path) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(toArtifactsJsonString());
  }
}
