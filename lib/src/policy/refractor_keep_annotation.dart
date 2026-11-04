import 'package:kernel/kernel.dart';

/// Detects `@Refractor.keep()` markers from the `refractor_annotation` package.
final class RefractorKeepAnnotation {
  const RefractorKeepAnnotation._();

  static final Set<Uri> _annotationUris = {
    Uri.parse('package:refractor_annotation/refractor_annotation.dart'),
    Uri.parse('package:refractor_annotation/src/refractor.dart'),
  };

  static bool isPresentOn(List<Expression> annotations) {
    for (final annotation in annotations) {
      if (annotation is ConstantExpression) {
        final constant = annotation.constant;
        if (constant is InstanceConstant &&
            constant.classNode.name == 'RefractorKeep' &&
            _annotationUris.contains(
              constant.classNode.enclosingLibrary.importUri,
            )) {
          return true;
        }
      }
    }
    return false;
  }
}
