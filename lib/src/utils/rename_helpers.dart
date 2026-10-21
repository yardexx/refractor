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

bool hasRefractorVirtualizeAnnotation(List<Expression> annotations) {
  for (final ann in annotations) {
    if (ann is ConstantExpression) {
      final c = ann.constant;
      if (c is InstanceConstant &&
          c.classNode.name == 'RefractorVirtualize' &&
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
