import 'package:kernel/kernel.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/engine/engine.dart';
import 'package:refractor/src/engine/kernel/kernel_io.dart';
import 'package:refractor/src/utils/result.dart';
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

    test('runs compile -> load -> write -> target compile for exe', () {
      final result = engine.run(
        config: RefractorConfig(passes: []),
        request: const BuildRequest(
          input: 'lib/main.dart',
          output: 'build/out',
          target: Target.exe,
          workDirectory: '.dart_tool/refractor',
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

      expect(result, isA<Ok<BuildResult>>());
      final ok = result as Ok<BuildResult>;
      expect(ok.value.outputPath, 'build/out');
      expect(ok.value.passesRun, isEmpty);
      expect(ok.value.symbolTable.size, 0);
    });

    test(
      'writes final kernel output and skips compileToTarget for kernel target',
      () {
        final result = engine.run(
          config: RefractorConfig(passes: []),
          request: const BuildRequest(
            input: 'lib/main.dart',
            output: 'build/out.dill',
            target: Target.kernel,
            workDirectory: '.dart_tool/refractor',
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
        expect(result, isA<Ok<BuildResult>>());
        final ok = result as Ok<BuildResult>;
        expect(ok.value.outputPath, 'build/out.dill');
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
