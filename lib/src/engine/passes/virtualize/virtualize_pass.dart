import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/virtualize/config/virtualize_config.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/assembler.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/lowering/lowerer.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/vm_ir.dart';
import 'package:refractor/src/engine/passes/virtualize/reporting/virtualization_record.dart';
import 'package:refractor/src/engine/passes/virtualize/reporting/virtualize_artifact.dart';
import 'package:refractor/src/engine/passes/virtualize/runtime/interpreter_injector.dart';
import 'package:refractor/src/engine/passes/virtualize/selection/virtualize_selector.dart';
import 'package:refractor/src/engine/passes/virtualize/validation/virtualize_validator.dart';
import 'package:refractor/src/project/project_scope.dart';

/// Code-virtualization pass (M0 skeleton).
///
/// Replaces the body of each `@Refractor.virtualize()`-annotated, eligible
/// function with a call to a per-function switch-loop bytecode interpreter it
/// synthesizes and injects. M0 supports a restricted int/bool expression subset
/// with a fixed ISA and plaintext bytecode; per-build diversity, encoding, and
/// MBA handlers are later milestones (see docs/02-architecture.md).
class VirtualizePass extends Pass {
  VirtualizePass({required this.config, required this.projectScope});

  final VirtualizePassConfig config;
  final ProjectScope projectScope;

  @override
  String get name => 'virtualize';

  @override
  Future<PassResult> run(Component component) async {
    try {
      final selection = VirtualizeSelector(
        projectScope: projectScope,
      ).select(component);

      final injector = InterpreterInjector(component);
      final records = <VirtualizationRecord>[];
      var virtualizedCount = 0;

      for (final target in selection.targets) {
        final functionName = target.name.text;
        final program = lowerFunction(target.function);
        if (program == null) {
          records.add(
            VirtualizationRecord(
              functionName: functionName,
              virtualized: false,
              skipReason: 'outside M0 subset',
            ),
          );
          continue;
        }
        final opCount = program.items.whereType<VmInstr>().length;
        if (opCount > config.maxOps) {
          records.add(
            VirtualizationRecord(
              functionName: functionName,
              virtualized: false,
              skipReason: 'exceeds max_ops (${config.maxOps})',
            ),
          );
          continue;
        }
        final AssembledProgram assembled;
        try {
          assembled = assembleProgram(program);
        } on StackDepthError catch (error) {
          records.add(
            VirtualizationRecord(
              functionName: functionName,
              virtualized: false,
              skipReason: error.message,
            ),
          );
          continue;
        }

        final library = target.enclosingLibrary;
        final interpreter = injector.inject(library, assembled.stackDepth);
        final body = injector.buildReplacementBody(
          interpreter: interpreter,
          words: assembled.words,
          params: target.function.positionalParameters,
          returnsBool: assembled.returnsBool,
        );
        target.function.body = body..parent = target.function;
        virtualizedCount++;
        records.add(
          VirtualizationRecord(
            functionName: functionName,
            virtualized: true,
            opCount: opCount,
            bytecodeLength: assembled.words.length,
            stackDepth: assembled.stackDepth,
          ),
        );
      }

      if (virtualizedCount > 0) {
        final error = const VirtualizeValidator().verify(component);
        if (error != null) {
          return PassFailed(
            error: Exception('kernel verification failed: $error'),
            report: PassReport(passName: name, message: error),
          );
        }
      }

      return PassSucceeded(
        artifact: records.isEmpty ? null : VirtualizeArtifact(records: records),
        report: PassReport(
          passName: name,
          metadata: virtualizedCount == 0
              ? const {}
              : {'functions_virtualized': virtualizedCount.toString()},
        ),
      );
    } on Object catch (error) {
      final exception = error is Exception
          ? error
          : Exception(error.toString());
      return PassFailed(
        error: exception,
        report: PassReport(passName: name, message: error.toString()),
      );
    }
  }
}
