import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/string_encrypt/runtime/string_encrypt_setup_result.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

final class DecodeHelperInjector {
  DecodeHelperInjector({
    required ObfuscationScope scope,
  }) : _scope = scope;

  static const String helperBaseName = r'_obfDecode$';

  final ObfuscationScope _scope;

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
      if (_scope.shouldObfuscateLibrary(library)) {
        return library;
      }
    }
    return null;
  }

  Procedure _injectHelper(Library library, Component component) {
    final context = _resolveKernelContext(component);

    // String _obfDecode$(List<int> bytes, int key)
    final bytesParam = VariableDeclaration('bytes', type: context.listIntType);
    final keyParam = VariableDeclaration('key', type: context.intType);

    // var shift = 0;
    final shiftVar = VariableDeclaration(
      'shift',
      type: context.intType,
      initializer: IntLiteral(0),
    );

    final procedure = _buildDecodeProcedure(
      library: library,
      context: context,
      bytesParam: bytesParam,
      keyParam: keyParam,
      shiftVar: shiftVar,
    );
    library.addProcedure(procedure);
    return procedure;
  }

  // Resolves the SDK members needed to build:
  // Utf8Codec().decode(List<int>.of(bytes.reversed.map(...)))
  _DecodeHelperKernelContext _resolveKernelContext(Component component) {
    final coreLibrary = component.libraries.firstWhere(
      (candidate) => candidate.importUri.toString() == 'dart:core',
    );
    final convertLibrary = component.libraries.firstWhere(
      (candidate) => candidate.importUri.toString() == 'dart:convert',
    );
    final intClass = coreLibrary.classes.firstWhere((cls) => cls.name == 'int');
    final numClass = coreLibrary.classes.firstWhere((cls) => cls.name == 'num');
    final stringClass = coreLibrary.classes.firstWhere(
      (cls) => cls.name == 'String',
    );
    final iterableClass = coreLibrary.classes.firstWhere(
      (cls) => cls.name == 'Iterable',
    );
    final listClass = coreLibrary.classes.firstWhere(
      (cls) => cls.name == 'List',
    );
    final pragmaClass = coreLibrary.classes.firstWhere(
      (cls) => cls.name == 'pragma',
    );
    final utf8CodecClass = convertLibrary.classes.firstWhere(
      (cls) => cls.name == 'Utf8Codec',
    );

    final intType = InterfaceType(intClass, Nullability.nonNullable);
    final stringType = InterfaceType(stringClass, Nullability.nonNullable);
    final iterableIntType = InterfaceType(
      iterableClass,
      Nullability.nonNullable,
      [intType],
    );
    final listIntType = InterfaceType(listClass, Nullability.nonNullable, [
      intType,
    ]);

    return _DecodeHelperKernelContext(
      intType: intType,
      stringType: stringType,
      iterableIntType: iterableIntType,
      listIntType: listIntType,
      shiftRightMethod: intClass.procedures.firstWhere(
        (procedure) => procedure.name.text == '>>',
      ),
      bitAndMethod: intClass.procedures.firstWhere(
        (procedure) => procedure.name.text == '&',
      ),
      xorMethod: intClass.procedures.firstWhere(
        (procedure) => procedure.name.text == '^',
      ),
      addMethod: numClass.procedures.firstWhere(
        (procedure) => procedure.name.text == '+',
      ),
      reversedGetter: listClass.procedures.firstWhere(
        (procedure) => procedure.name.text == 'reversed',
      ),
      mapMethod: iterableClass.procedures.firstWhere(
        (procedure) => procedure.name.text == 'map',
      ),
      listOfFactory: listClass.procedures.firstWhere(
        (procedure) => procedure.name.text == 'of',
      ),
      decodeMethod: utf8CodecClass.procedures.firstWhere(
        (procedure) => procedure.name.text == 'decode',
      ),
      utf8CodecConstructor: utf8CodecClass.constructors.single,
      pragmaClass: pragmaClass,
      pragmaNameField: pragmaClass.fields.firstWhere(
        (field) => field.name.text == 'name',
      ),
      pragmaOptionsField: pragmaClass.fields.firstWhere(
        (field) => field.name.text == 'options',
      ),
    );
  }

  Procedure _buildDecodeProcedure({
    required Library library,
    required _DecodeHelperKernelContext context,
    required VariableDeclaration bytesParam,
    required VariableDeclaration keyParam,
    required VariableDeclaration shiftVar,
  }) {
    final decodeCall = _buildDecodeCall(
      context: context,
      bytesParam: bytesParam,
      keyParam: keyParam,
      shiftVar: shiftVar,
    );

    // @pragma('vm:never-inline')
    // String _obfDecode$(List<int> bytes, int key) {
    //   var shift = 0;
    //   return Utf8Codec().decode(List<int>.of(bytes.reversed.map(...)));
    // }
    return Procedure(
      Name(_freshHelperName(library), library),
      ProcedureKind.Method,
      FunctionNode(
        Block([
          shiftVar,
          ReturnStatement(decodeCall),
        ]),
        positionalParameters: [bytesParam, keyParam],
        requiredParameterCount: 2,
        returnType: context.stringType,
      ),
      fileUri: library.fileUri,
      isStatic: true,
    )..addAnnotation(_buildNeverInlineAnnotation(context));
  }

  // Utf8Codec().decode(List<int>.of(bytes.reversed.map((byte) { ... })))
  InstanceInvocation _buildDecodeCall({
    required _DecodeHelperKernelContext context,
    required VariableDeclaration bytesParam,
    required VariableDeclaration keyParam,
    required VariableDeclaration shiftVar,
  }) {
    final mappedBytes = _buildMappedDecodedBytes(
      context: context,
      bytesParam: bytesParam,
      keyParam: keyParam,
      shiftVar: shiftVar,
    );

    // List<int>.of(mappedBytes)
    final byteList = StaticInvocation(
      context.listOfFactory,
      Arguments([mappedBytes], types: [context.intType]),
    );

    // The function type for Utf8Codec().decode(List<int>)
    final decodeFunctionType = FunctionType(
      [context.listIntType],
      context.stringType,
      Nullability.nonNullable,
    );

    // Utf8Codec().decode(...)
    return InstanceInvocation(
      InstanceAccessKind.Instance,
      ConstructorInvocation(
        context.utf8CodecConstructor,
        Arguments.empty(),
      ),
      Name('decode'),
      Arguments([byteList]),
      interfaceTarget: context.decodeMethod,
      functionType: decodeFunctionType,
    );
  }

  // bytes.reversed.map((byte) {
  //    final decoded = ...;
  //    shift = ...;
  //    return decoded;
  // })`
  InstanceInvocation _buildMappedDecodedBytes({
    required _DecodeHelperKernelContext context,
    required VariableDeclaration bytesParam,
    required VariableDeclaration keyParam,
    required VariableDeclaration shiftVar,
  }) {
    // bytes.reversed
    final reversedBytes = InstanceGet(
      InstanceAccessKind.Instance,
      VariableGet(bytesParam),
      Name('reversed'),
      interfaceTarget: context.reversedGetter,
      resultType: context.iterableIntType,
    );

    // The function type for the map lambda: (int) -> int
    final lambdaType = FunctionType(
      [context.intType],
      context.intType,
      Nullability.nonNullable,
    );

    // The function type for the map method: (int) -> int
    final mapFunctionType = FunctionType(
      [lambdaType],
      context.iterableIntType,
      Nullability.nonNullable,
    );

    // bytes.reversed.map(...)
    return InstanceInvocation(
      InstanceAccessKind.Instance,
      reversedBytes,
      Name('map'),
      Arguments(
        [
          _buildDecodeMapLambda(
            context: context,
            keyParam: keyParam,
            shiftVar: shiftVar,
          ),
        ],
        types: [context.intType],
      ),
      interfaceTarget: context.mapMethod,
      functionType: mapFunctionType,
    );
  }

  // (byte) {
  //   final decoded = byte ^ ((key >> shift) & 0xFF);
  //   shift = (shift + 8) & 24;
  //   return decoded;
  // }
  FunctionExpression _buildDecodeMapLambda({
    required _DecodeHelperKernelContext context,
    required VariableDeclaration keyParam,
    required VariableDeclaration shiftVar,
  }) {
    // The parameter for the lambda: (int byte)
    final byteParam = VariableDeclaration('byte', type: context.intType);

    // The variable declaration for the decoded byte: final decoded = ...
    final decodedVar = VariableDeclaration(
      'decoded',
      type: context.intType,
      initializer: _buildDecodedByteExpression(
        context: context,
        byteParam: byteParam,
        keyParam: keyParam,
        shiftVar: shiftVar,
      ),
    );

    // {
    //   final decoded = byte ^ ((key >> shift) & 0xFF);
    //   shift = (shift + 8) & 24;
    //   return decoded;
    // }
    return FunctionExpression(
      FunctionNode(
        Block([
          decodedVar,
          _buildShiftUpdateStatement(
            context: context,
            shiftVar: shiftVar,
          ),
          ReturnStatement(VariableGet(decodedVar)),
        ]),
        positionalParameters: [byteParam],
        requiredParameterCount: 1,
        returnType: context.intType,
      ),
    );
  }

  // byte ^ ((key >> shift) & 0xFF)
  InstanceInvocation _buildDecodedByteExpression({
    required _DecodeHelperKernelContext context,
    required VariableDeclaration byteParam,
    required VariableDeclaration keyParam,
    required VariableDeclaration shiftVar,
  }) {
    final intBinaryFunctionType = FunctionType(
      [context.intType],
      context.intType,
      Nullability.nonNullable,
    );

    // key >> shift
    final shiftedKey = InstanceInvocation(
      InstanceAccessKind.Instance,
      VariableGet(keyParam),
      Name('>>'),
      Arguments([VariableGet(shiftVar)]),
      interfaceTarget: context.shiftRightMethod,
      functionType: intBinaryFunctionType,
    );

    // (key >> shift) & 0xFF
    final maskedKeyByte = InstanceInvocation(
      InstanceAccessKind.Instance,
      shiftedKey,
      Name('&'),
      Arguments([IntLiteral(0xFF)]),
      interfaceTarget: context.bitAndMethod,
      functionType: intBinaryFunctionType,
    );

    // byte ^ ((key >> shift) & 0xFF)
    return InstanceInvocation(
      InstanceAccessKind.Instance,
      VariableGet(byteParam),
      Name('^'),
      Arguments([maskedKeyByte]),
      interfaceTarget: context.xorMethod,
      functionType: intBinaryFunctionType,
    );
  }

  // shift = (shift + 8) & 24
  ExpressionStatement _buildShiftUpdateStatement({
    required _DecodeHelperKernelContext context,
    required VariableDeclaration shiftVar,
  }) {
    final intBinaryFunctionType = FunctionType(
      [context.intType],
      context.intType,
      Nullability.nonNullable,
    );

    // shift + 8
    final advancedShift = InstanceInvocation(
      InstanceAccessKind.Instance,
      VariableGet(shiftVar),
      Name('+'),
      Arguments([IntLiteral(8)]),
      interfaceTarget: context.addMethod,
      functionType: intBinaryFunctionType,
    );

    // shift = (shift + 8) & 24
    return ExpressionStatement(
      VariableSet(
        shiftVar,
        InstanceInvocation(
          InstanceAccessKind.Instance,
          advancedShift,
          Name('&'),
          Arguments([IntLiteral(24)]),
          interfaceTarget: context.bitAndMethod,
          functionType: intBinaryFunctionType,
        ),
      ),
    );
  }

  // @pragma('vm:never-inline')
  ConstantExpression _buildNeverInlineAnnotation(
    _DecodeHelperKernelContext context,
  ) {
    // @pragma('vm:never-inline')
    return ConstantExpression(
      InstanceConstant(
        context.pragmaClass.reference,
        const [],
        <Reference, Constant>{
          context.pragmaNameField.fieldReference: StringConstant(
            'vm:never-inline',
          ),
          context.pragmaOptionsField.fieldReference: NullConstant(),
        },
      ),
    );
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

final class _DecodeHelperKernelContext {
  const _DecodeHelperKernelContext({
    required this.intType,
    required this.stringType,
    required this.iterableIntType,
    required this.listIntType,
    required this.shiftRightMethod,
    required this.bitAndMethod,
    required this.xorMethod,
    required this.addMethod,
    required this.reversedGetter,
    required this.mapMethod,
    required this.listOfFactory,
    required this.decodeMethod,
    required this.utf8CodecConstructor,
    required this.pragmaClass,
    required this.pragmaNameField,
    required this.pragmaOptionsField,
  });

  final InterfaceType intType;
  final InterfaceType stringType;
  final InterfaceType iterableIntType;
  final InterfaceType listIntType;
  final Procedure shiftRightMethod;
  final Procedure bitAndMethod;
  final Procedure xorMethod;
  final Procedure addMethod;
  final Procedure reversedGetter;
  final Procedure mapMethod;
  final Procedure listOfFactory;
  final Procedure decodeMethod;
  final Constructor utf8CodecConstructor;
  final Class pragmaClass;
  final Field pragmaNameField;
  final Field pragmaOptionsField;
}
