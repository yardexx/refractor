import 'package:kernel/kernel.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/engine/engine.dart';
import 'package:refractor/src/engine/kernel/helper_source.dart';
import 'package:refractor/src/engine/kernel/kernel_io.dart';
import 'package:refractor/src/engine/kernel/runtime_helpers.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/engine/pass/config/pass_definition.dart';
import 'package:refractor/src/engine/pass/pass_registry.dart';
import 'package:refractor/src/policy/keep_source.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';
import 'package:test/test.dart';

void main() {
  group('RefractorEngine.run', () {
    late _FakeCompiler compiler;
    late _FakeKernelIo kernelIo;
    late RefractorEngine engine;

    setUp(() {
      compiler = _FakeCompiler();
      kernelIo = _FakeKernelIo();
      engine = RefractorEngine(compiler: compiler, kernelIO: kernelIo);
    });

    test('runs compile -> load -> write -> target compile for exe', () async {
      final result = await engine.run(
        config: RefractorConfig(passes: []),
        request: BuildRequest(
          input: 'lib/main.dart',
          output: 'build/out',
          target: Target.exe,
          workDirectory: '.dart_tool/refractor',
          projectRootUri: Uri(scheme: 'file', path: '/project/'),
          projectPackageName: 'sample_app',
        ),
      );

      expect(compiler.compileToKernelCalls, hasLength(1));
      expect(
        compiler.compileToKernelCalls.single,
        ('lib/main.dart', '.dart_tool/refractor/app.dill'),
      );

      expect(kernelIo.loadCalls, ['.dart_tool/refractor/app.dill']);
      expect(kernelIo.writeCalls, hasLength(1));
      expect(
        kernelIo.writeCalls.single.path,
        '.dart_tool/refractor/app.obfuscated.dill',
      );

      expect(compiler.compileToTargetCalls, hasLength(1));
      final targetCall = compiler.compileToTargetCalls.single;
      expect(targetCall.dillPath, '.dart_tool/refractor/app.obfuscated.dill');
      expect(targetCall.outputPath, 'build/out');
      expect(targetCall.target, Target.exe);

      expect(result.outputPath, 'build/out');
      expect(result.passesRun, isEmpty);
      expect(result.passResults.artifacts, isEmpty);
      expect(result.failures, isEmpty);
    });

    test(
      'writes final kernel output and skips compileToTarget for kernel target',
      () async {
        final result = await engine.run(
          config: RefractorConfig(passes: []),
          request: BuildRequest(
            input: 'lib/main.dart',
            output: 'build/out.dill',
            target: Target.kernel,
            workDirectory: '.dart_tool/refractor',
            projectRootUri: Uri(scheme: 'file', path: '/project/'),
            projectPackageName: 'sample_app',
          ),
        );

        expect(compiler.compileToTargetCalls, isEmpty);
        expect(kernelIo.writeCalls, hasLength(2));
        expect(
          kernelIo.writeCalls.map((c) => c.path),
          [
            '.dart_tool/refractor/app.obfuscated.dill',
            'build/out.dill',
          ],
        );
        expect(result.outputPath, 'build/out.dill');
      },
    );

    test('passesRun reflects YAML pass order', () async {
      final result = await engine.run(
        config: RefractorConfig.fromYaml('''
refractor:
  passes:
    string_encrypt: true
    rename: true
'''),
        request: BuildRequest(
          input: 'lib/main.dart',
          output: 'build/out',
          target: Target.exe,
          workDirectory: '.dart_tool/refractor',
          projectRootUri: Uri(scheme: 'file', path: '/project/'),
          projectPackageName: 'sample_app',
        ),
      );

      expect(result.passesRun, ['string_encrypt', 'rename']);
    });

    test(
      'pass failure is reported and output generation is skipped',
      () async {
        engine = RefractorEngine(
          compiler: compiler,
          kernelIO: kernelIo,
          passRegistry: PassRegistry([_FailingDefinition()]),
        );

        final result = await engine.run(
          config: RefractorConfig(passes: [const _FailingPassConfig()]),
          request: BuildRequest(
            input: 'lib/main.dart',
            output: 'build/out',
            target: Target.exe,
            workDirectory: '.dart_tool/refractor',
            projectRootUri: Uri(scheme: 'file', path: '/project/'),
            projectPackageName: 'sample_app',
          ),
        );

        expect(result.failures, hasLength(1));
        expect(result.failures.single.passName, 'string_encrypt');
        expect(result.reports, hasLength(1));
        expect(result.reports.single.passName, 'string_encrypt');
        expect(result.reports.single.message, isNotNull);
        expect(kernelIo.writeCalls, isEmpty);
        expect(compiler.compileToTargetCalls, isEmpty);
      },
    );
  });
}

class _FakeCompiler implements Compiler {
  final List<(String, String)> compileToKernelCalls = [];
  final List<_TargetCall> compileToTargetCalls = [];

  @override
  void compileToKernel(String sourcePath, String outputPath) {
    compileToKernelCalls.add((sourcePath, outputPath));
  }

  @override
  void compileToTarget(String dillPath, String outputPath, Target target) {
    compileToTargetCalls.add(_TargetCall(dillPath, outputPath, target));
  }
}

class _TargetCall {
  _TargetCall(this.dillPath, this.outputPath, this.target);

  final String dillPath;
  final String outputPath;
  final Target target;
}

class _FakeKernelIo implements KernelIO {
  final Component component = Component();
  final List<String> loadCalls = [];
  final List<_WriteCall> writeCalls = [];

  @override
  Component load(String path) {
    loadCalls.add(path);
    return component;
  }

  @override
  void write(Component component, String path) {
    writeCalls.add(_WriteCall(component, path));
  }
}

class _WriteCall {
  _WriteCall(this.component, this.path);

  final Component component;
  final String path;
}

final class _FailingPassConfig extends PassConfig {
  const _FailingPassConfig();
}

final class _FailingDefinition implements PassDefinition<_FailingPassConfig> {
  @override
  String get name => 'string_encrypt';

  @override
  Set<KeepSource> get keepSources => const {};

  @override
  Set<HelperSource> get runtimeHelpers => const {};

  @override
  Pass createPass({
    required _FailingPassConfig config,
    required ObfuscationScope scope,
    required RuntimeHelpers helpers,
  }) {
    return _FailingPass();
  }

  @override
  _FailingPassConfig parseConfig(Map<String, dynamic> json) {
    return const _FailingPassConfig();
  }

  @override
  bool supports(PassConfig config) => config is _FailingPassConfig;
}

final class _FailingPass extends Pass {
  @override
  String get name => 'string_encrypt';

  @override
  Future<PassResult> run(Component component) async {
    return PassFailed(
      error: Exception('boom'),
      report: const PassReport(
        passName: 'string_encrypt',
        message: 'boom',
      ),
    );
  }
}
