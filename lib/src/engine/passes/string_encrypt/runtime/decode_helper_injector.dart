import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/string_encrypt/runtime/string_encrypt_setup_result.dart';
import 'package:refractor/src/policy/string_encrypt_policy_view.dart';
import 'package:refractor/src/project/project_scope.dart';

final class DecodeHelperInjector {
  DecodeHelperInjector({
    required ProjectScope projectScope,
    required StringEncryptPolicyView policy,
  }) : _projectScope = projectScope,
       _policy = policy;

  static const String helperBaseName = r'_obfDecode$';

  final ProjectScope _projectScope;
  final StringEncryptPolicyView _policy;

  StringEncryptSetupResult? injectIntoFirstEligibleLibrary(
    Component component,
  ) {
    final targetLibrary = _findFirstEligibleLibrary(component);
    if (targetLibrary == null) {
      return null;
    }

    final decodeProcedure = _injectHelper(targetLibrary, component);
    return StringEncryptSetupResult(
      targetLibrary: targetLibrary,
      decodeProcedure: decodeProcedure,
    );
  }

  Library? _findFirstEligibleLibrary(Component component) {
    for (final library in component.libraries) {
      if (_projectScope.containsLibrary(library) &&
          !_policy.isLibraryKept(library)) {
        return library;
      }
    }
    return null;
  }

  Procedure _injectHelper(Library library, Component component) {
    final coreLibrary = component.libraries.firstWhere(
      (candidate) => candidate.importUri.toString() == 'dart:core',
    );
    final intClass = coreLibrary.classes.firstWhere((cls) => cls.name == 'int');
    final stringClass = coreLibrary.classes.firstWhere(
      (cls) => cls.name == 'String',
    );
    final iterableClass = coreLibrary.classes.firstWhere(
      (cls) => cls.name == 'Iterable',
    );
    final listClass = coreLibrary.classes.firstWhere(
      (cls) => cls.name == 'List',
    );

    final intType = InterfaceType(intClass, Nullability.nonNullable);
    final stringType = InterfaceType(stringClass, Nullability.nonNullable);
    final listIntType = InterfaceType(listClass, Nullability.nonNullable, [
      intType,
    ]);

    final bytesParam = VariableDeclaration('bytes', type: listIntType);
    final keyParam = VariableDeclaration('key', type: intType);
    final byteParam = VariableDeclaration('b', type: intType);

    final xorMethod = intClass.procedures.firstWhere(
      (procedure) => procedure.name.text == '^',
    );
    final xorFunctionType = FunctionType(
      [intType],
      intType,
      Nullability.nonNullable,
    );
    final xorExpression = InstanceInvocation(
      InstanceAccessKind.Instance,
      VariableGet(byteParam),
      Name('^'),
      Arguments([VariableGet(keyParam)]),
      interfaceTarget: xorMethod,
      functionType: xorFunctionType,
    );

    final lambda = FunctionExpression(
      FunctionNode(
        ReturnStatement(xorExpression),
        positionalParameters: [byteParam],
        requiredParameterCount: 1,
        returnType: intType,
      ),
    );

    final mapMethod = iterableClass.procedures.firstWhere(
      (procedure) => procedure.name.text == 'map',
    );
    final iterableIntType = InterfaceType(
      iterableClass,
      Nullability.nonNullable,
      [intType],
    );
    final mapFunctionType = FunctionType(
      [
        FunctionType([intType], intType, Nullability.nonNullable),
      ],
      iterableIntType,
      Nullability.nonNullable,
    );
    final mapCall = InstanceInvocation(
      InstanceAccessKind.Instance,
      VariableGet(bytesParam),
      Name('map'),
      Arguments([lambda]),
      interfaceTarget: mapMethod,
      functionType: mapFunctionType,
    );

    final fromCharCodesFactory = stringClass.procedures.firstWhere(
      (procedure) => procedure.name.text == 'fromCharCodes',
    );
    final fromCharCodesCall = StaticInvocation(
      fromCharCodesFactory,
      Arguments([mapCall]),
    );

    final procedure = Procedure(
      Name(_freshHelperName(library), library),
      ProcedureKind.Method,
      FunctionNode(
        ReturnStatement(fromCharCodesCall),
        positionalParameters: [bytesParam, keyParam],
        requiredParameterCount: 2,
        returnType: stringType,
      ),
      fileUri: library.fileUri,
      isStatic: true,
    );

    library.addProcedure(procedure);
    return procedure;
  }

  String _freshHelperName(Library library) {
    final usedNames = <String>{
      for (final procedure in library.procedures) procedure.name.text,
      for (final field in library.fields) field.name.text,
    };

    if (!usedNames.contains(helperBaseName)) {
      return helperBaseName;
    }

    var suffix = 1;
    while (usedNames.contains('$helperBaseName$suffix')) {
      suffix++;
    }
    return '$helperBaseName$suffix';
  }
}
