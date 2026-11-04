import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/kernel_toolkit/sdk/helper_injector.dart';
import 'package:refractor/src/engine/kernel_toolkit/sdk/sdk_index.dart';
import 'package:test/test.dart';

import '../../../helpers/kernel_helpers.dart';

void main() {
  final injector = KernelHelperInjector(scope: makeObfuscationScope());

  test('firstEligibleLibrary returns the first project library', () {
    final userLib = makeUserLibrary();
    final component = makeComponent(
      coreLib: makeDartCoreLibrary(),
      userLib: userLib,
    );

    expect(injector.firstEligibleLibrary(component), same(userLib));
  });

  test('freshTopLevelName avoids existing procedure names', () {
    final lib = makeUserLibrary();
    void addProcedure(String name) => lib.addProcedure(
      Procedure(
        Name(name, lib),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        isStatic: true,
        fileUri: lib.fileUri,
      ),
    );

    expect(injector.freshTopLevelName(lib, '_helper'), '_helper');

    addProcedure('_helper');
    expect(injector.freshTopLevelName(lib, '_helper'), '_helper1');

    addProcedure('_helper1');
    expect(injector.freshTopLevelName(lib, '_helper'), '_helper2');
  });

  test('addStaticProcedure adds a static procedure with annotations', () {
    final lib = makeUserLibrary();
    final sdk = SdkIndex(
      makeComponent(coreLib: makeDartCoreLibrary(), userLib: lib),
    );

    final procedure = injector.addStaticProcedure(
      lib,
      name: Name('_x', lib),
      function: FunctionNode(EmptyStatement()),
      annotations: [injector.pragma(sdk, 'vm:never-inline')],
    );

    expect(procedure.isStatic, isTrue);
    expect(lib.procedures, contains(procedure));
    expect(procedure.annotations, isNotEmpty);
  });

  test('pragma builds an InstanceConstant annotation', () {
    final sdk = SdkIndex(
      makeComponent(coreLib: makeDartCoreLibrary(), userLib: makeUserLibrary()),
    );

    final annotation = injector.pragma(sdk, 'vm:never-inline');

    expect(annotation.constant, isA<InstanceConstant>());
  });
}
