import 'package:glob/glob.dart';
import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/policy/obfuscation_policy_resolver.dart';
import 'package:refractor/src/engine/runner/obfuscation_target.dart';
import 'package:test/test.dart';

import '../../helpers/kernel_helpers.dart';

void main() {
  group('ObfuscationPolicyResolver', () {
    late Library coreLib;
    late Library userLib;

    setUp(() {
      coreLib = makeDartCoreLibrary();
      userLib = makeUserLibrary();
    });

    test('target exclusions mark library as excluded from all obfuscation', () {
      final excludedLib = makeUserLibrary('src/ignored.dart');
      final component = Component(libraries: [coreLib, excludedLib])
        ..setMainMethodAndMode(null, true);
      final target = ObfuscationTarget(
        projectRootUri: Uri.directory('/virtual/project'),
        projectPackageName: 'refractor',
        excludePatterns: [Glob('**/ignored.dart')],
      );

      final policy = ObfuscationPolicyResolver().resolve(component, target);

      expect(
        policy.policyForLibrary(excludedLib).excludeFromAllObfuscation,
        isTrue,
      );
    });

    test('pragma excludes rename without excluding all obfuscation', () {
      final pragmaClass = Class(name: 'pragma', fileUri: coreLib.fileUri);
      coreLib.addClass(pragmaClass);

      final procedure =
          Procedure(
            Name('kept'),
            ProcedureKind.Method,
            FunctionNode(EmptyStatement()),
            fileUri: userLib.fileUri,
          )..addAnnotation(
            ConstantExpression(
              InstanceConstant(pragmaClass.reference, [], {}),
            ),
          );
      userLib.addProcedure(procedure);
      final component = makeComponent(coreLib: coreLib, userLib: userLib);

      final policy = ObfuscationPolicyResolver().resolve(
        component,
        makeObfuscationTarget(),
      );

      final memberPolicy = policy.policyForMember(procedure);
      expect(memberPolicy.excludeFromAllObfuscation, isFalse);
      expect(memberPolicy.excludeFromRename, isTrue);
      expect(memberPolicy.excludeFromStringEncryption, isFalse);
      expect(memberPolicy.excludeParametersFromRename, isTrue);
    });

    test('preserved main excludes parameters from rename', () {
      final mainProcedure = Procedure(
        Name('main'),
        ProcedureKind.Method,
        FunctionNode(
          EmptyStatement(),
          namedParameters: [VariableDeclaration('debug')],
        ),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(mainProcedure);
      final component = makeComponent(coreLib: coreLib, userLib: userLib);

      final policy = ObfuscationPolicyResolver().resolve(
        component,
        makeObfuscationTarget(),
      );

      final memberPolicy = policy.policyForMember(mainProcedure);
      expect(memberPolicy.excludeFromRename, isTrue);
      expect(memberPolicy.excludeParametersFromRename, isTrue);
    });

    test('main exclusion remains rename-specific, not global', () {
      final mainProcedure = Procedure(
        Name('main'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(mainProcedure);
      final component = makeComponent(coreLib: coreLib, userLib: userLib);

      final policy = ObfuscationPolicyResolver().resolve(
        component,
        makeObfuscationTarget(),
      );

      final memberPolicy = policy.policyForMember(mainProcedure);
      expect(memberPolicy.excludeFromAllObfuscation, isFalse);
      expect(memberPolicy.excludeFromRename, isTrue);
      expect(memberPolicy.excludeFromStringEncryption, isFalse);
    });
  });
}
