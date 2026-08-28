import 'package:kernel/kernel.dart';

final Set<Uri> _refractorAnnotationUris = {
  Uri.parse('package:refractor_annotation/refractor_annotation.dart'),
  Uri.parse('package:refractor_annotation/src/refractor.dart'),
};

String memberNameText(Member member) => switch (member) {
  final Procedure p => p.name.text,
  final Field f => f.name.text,
  final Constructor c => c.name.text,
};

bool hasRefractorKeepAnnotation(List<Expression> annotations) {
  for (final ann in annotations) {
    if (ann is ConstantExpression) {
      final c = ann.constant;
      if (c is InstanceConstant &&
          c.classNode.name == 'RefractorKeep' &&
          _refractorAnnotationUris.contains(
            c.classNode.enclosingLibrary.importUri,
          )) {
        return true;
      }
    }
  }
  return false;
}

String symbolKeyForName(Name name) {
  final library = name.library;
  if (library == null) return name.text;
  return '${library.importUri}::${name.text}';
}

/// Whether two kernel [Name]s are the same identifier in the same privacy
/// scope. Private names are only equal when they share the same library, so
/// text equality alone is insufficient.
bool sameName(Name a, Name b) {
  return a.text == b.text && identical(a.library, b.library);
}
