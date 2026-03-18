import 'package:kernel/kernel.dart';

String memberNameText(Member member) => switch (member) {
  final Procedure p => p.name.text,
  final Field f => f.name.text,
  final Constructor c => c.name.text,
};

bool hasEntryPointPragma(List<Expression> annotations) {
  for (final ann in annotations) {
    if (ann is ConstantExpression) {
      final c = ann.constant;
      if (c is InstanceConstant && c.classNode.name == 'pragma') return true;
    }
  }
  return false;
}

String symbolKeyForName(Name name) {
  final library = name.library;
  if (library == null) return name.text;
  return '${library.importUri}::${name.text}';
}
