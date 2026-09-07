import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/sdk/helper_injector.dart';
import 'package:refractor/src/engine/kernel_toolkit/sdk/sdk_index.dart';
import 'package:refractor/src/engine/passes/string_encrypt/runtime/string_encrypt_setup_result.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

final class DecodeHelperInjector {
  DecodeHelperInjector({
    required ObfuscationScope scope,
  }) : _injector = KernelHelperInjector(scope: scope);

  static const String helperBaseName = r'_obfDecode$';

  final KernelHelperInjector _injector;

  StringEncryptSetupResult? injectIntoFirstEligibleLibrary(
    Component component,
  ) {
    final targetLibrary = _injector.firstEligibleLibrary(component);
    if (targetLibrary == null) {
      return null;
    }

    final decodeProcedure = _injectHelper(targetLibrary, component);
    return StringEncryptSetupResult(
      targetLibrary: targetLibrary,
      decodeProcedure: decodeProcedure,
    );
  }

  Procedure _injectHelper(Library library, Component component) {
    final sdk = SdkIndex(component);
    final context = _resolveKernelContext(sdk);

    final bytesParam = VariableDeclaration('bytes', type: context.listIntType);
    final keyParam = VariableDeclaration('key', type: context.intType);
    final shiftVar = VariableDeclaration(
      'shift',
      type: context.intType,
      initializer: IntLiteral(0),
    );

    final function = _buildDecodeFunction(
      context: context,
      bytesParam: bytesParam,
      keyParam: keyParam,
      shiftVar: shiftVar,
    );

    return _injector.addStaticProcedure(
      library,
      name: Name(_injector.freshTopLevelName(library, helperBaseName), library),
      function: function,
      annotations: [_injector.pragma(sdk, 'vm:never-inline')],
    );
  }

  _DecodeHelperKernelContext _resolveKernelContext(SdkIndex sdk) {
    final intClass = sdk.requireClass('dart:core', 'int');
    final numClass = sdk.requireClass('dart:core', 'num');
    final stringClass = sdk.requireClass('dart:core', 'String');
    final iterableClass = sdk.requireClass('dart:core', 'Iterable');
    final listClass = sdk.requireClass('dart:core', 'List');
    final utf8CodecClass = sdk.requireClass('dart:convert', 'Utf8Codec');

    final intType = sdk.interfaceType(intClass);
    final stringType = sdk.interfaceType(stringClass);
    final iterableIntType = sdk.interfaceType(
      iterableClass,
      typeArguments: [intType],
    );
    final listIntType = sdk.interfaceType(listClass, typeArguments: [intType]);

    return _DecodeHelperKernelContext(
      intType: intType,
      stringType: stringType,
      iterableIntType: iterableIntType,
      listIntType: listIntType,
      shiftRightMethod: sdk.requireProcedure(intClass, '>>'),
      bitAndMethod: sdk.requireProcedure(intClass, '&'),
      xorMethod: sdk.requireProcedure(intClass, '^'),
      addMethod: sdk.requireProcedure(numClass, '+'),
      reversedGetter: sdk.requireProcedure(listClass, 'reversed'),
      mapMethod: sdk.requireProcedure(iterableClass, 'map'),
      listOfFactory: sdk.requireProcedure(listClass, 'of'),
      decodeMethod: sdk.requireProcedure(utf8CodecClass, 'decode'),
      utf8CodecConstructor: sdk.requireSingleConstructor(utf8CodecClass),
    );
  }

  // @pragma('vm:never-inline')
  // String _obfDecode$(List<int> bytes, int key) {
  //   var shift = 0;
  //   return Utf8Codec().decode(List<int>.of(bytes.reversed.map(...)));
  // }
  FunctionNode _buildDecodeFunction({
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

    return FunctionNode(
      Block([
        shiftVar,
        ReturnStatement(decodeCall),
      ]),
      positionalParameters: [bytesParam, keyParam],
      requiredParameterCount: 2,
      returnType: context.stringType,
    );
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

    final byteList = StaticInvocation(
      context.listOfFactory,
      Arguments([mappedBytes], types: [context.intType]),
    );

    final decodeFunctionType = FunctionType(
      [context.listIntType],
      context.stringType,
      Nullability.nonNullable,
    );

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

  // bytes.reversed.map((byte) { ... })
  InstanceInvocation _buildMappedDecodedBytes({
    required _DecodeHelperKernelContext context,
    required VariableDeclaration bytesParam,
    required VariableDeclaration keyParam,
    required VariableDeclaration shiftVar,
  }) {
    final reversedBytes = InstanceGet(
      InstanceAccessKind.Instance,
      VariableGet(bytesParam),
      Name('reversed'),
      interfaceTarget: context.reversedGetter,
      resultType: context.iterableIntType,
    );

    final lambdaType = FunctionType(
      [context.intType],
      context.intType,
      Nullability.nonNullable,
    );

    final mapFunctionType = FunctionType(
      [lambdaType],
      context.iterableIntType,
      Nullability.nonNullable,
    );

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
    final byteParam = VariableDeclaration('byte', type: context.intType);

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

    final shiftedKey = InstanceInvocation(
      InstanceAccessKind.Instance,
      VariableGet(keyParam),
      Name('>>'),
      Arguments([VariableGet(shiftVar)]),
      interfaceTarget: context.shiftRightMethod,
      functionType: intBinaryFunctionType,
    );

    final maskedKeyByte = InstanceInvocation(
      InstanceAccessKind.Instance,
      shiftedKey,
      Name('&'),
      Arguments([IntLiteral(0xFF)]),
      interfaceTarget: context.bitAndMethod,
      functionType: intBinaryFunctionType,
    );

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

    final advancedShift = InstanceInvocation(
      InstanceAccessKind.Instance,
      VariableGet(shiftVar),
      Name('+'),
      Arguments([IntLiteral(8)]),
      interfaceTarget: context.addMethod,
      functionType: intBinaryFunctionType,
    );

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
}
