import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/sdk/sdk_index.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

final class KernelHelperInjector {
  KernelHelperInjector({required this.scope});

  final ObfuscationScope scope;

  Library? firstEligibleLibrary(Component component) {
    for (final library in component.libraries) {
      if (scope.shouldObfuscateLibrary(library)) return library;
    }
    return null;
  }

  String freshTopLevelName(Library library, String base) {
    final used = <String>{
      for (final procedure in library.procedures) procedure.name.text,
      for (final field in library.fields) field.name.text,
    };
    if (!used.contains(base)) return base;
    var suffix = 1;
    while (used.contains('$base$suffix')) {
      suffix++;
    }
    return '$base$suffix';
  }

  Procedure addStaticProcedure(
    Library library, {
    required Name name,
    required FunctionNode function,
    List<Expression> annotations = const [],
  }) {
    final procedure = Procedure(
      name,
      ProcedureKind.Method,
      function,
      fileUri: library.fileUri,
      isStatic: true,
    );
    annotations.forEach(procedure.addAnnotation);
    library.addProcedure(procedure);
    return procedure;
  }

  ConstantExpression pragma(SdkIndex sdk, String name, {Constant? options}) {
    final pragmaClass = sdk.requireClass('dart:core', 'pragma');
    final nameField = sdk.requireField(pragmaClass, 'name');
    final optionsField = sdk.requireField(pragmaClass, 'options');
    return ConstantExpression(
      InstanceConstant(pragmaClass.reference, const [], <Reference, Constant>{
        nameField.fieldReference: StringConstant(name),
        optionsField.fieldReference: options ?? NullConstant(),
      }),
    );
  }
}
