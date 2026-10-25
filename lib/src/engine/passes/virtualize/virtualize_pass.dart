import 'dart:math';

import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/virtualize/config/virtualize_config.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/assembler.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/isa.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/lowering/lowerer.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/lowering/superops.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/vm_ir.dart';
import 'package:refractor/src/engine/passes/virtualize/reporting/virtualization_record.dart';
import 'package:refractor/src/engine/passes/virtualize/reporting/virtualize_artifact.dart';
import 'package:refractor/src/engine/passes/virtualize/runtime/interpreter_injector.dart';
import 'package:refractor/src/engine/passes/virtualize/selection/virtualize_selector.dart';
import 'package:refractor/src/engine/passes/virtualize/validation/virtualize_validator.dart';
import 'package:refractor/src/project/project_scope.dart';

/// Code-virtualization pass (M1).
///
/// Replaces the body of each `@Refractor.virtualize()`-annotated, eligible
/// function with a call to a per-function switch-loop bytecode interpreter it
/// synthesizes and injects. Each function gets its own seed-derived
/// [IsaProfile] — an opcode permutation plus position-keyed XOR encoding of the
/// bytecode — so the dispatch numbering doesn't transfer across functions/builds
/// and the bytecode is not plaintext in the Dart object pool. Supports a
/// restricted int/bool expression subset; MBA handlers and environment-derived
/// keys are later milestones (see docs/02-architecture.md).
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
      final applied = <_AppliedTransform>[];
      var virtualizedCount = 0;
      // 0 => random ISA per build; a fixed seed => reproducible builds.
      final baseSeed = config.seed != 0
          ? config.seed
          : Random().nextInt(0xFFFFFFFF);

      for (var index = 0; index < selection.targets.length; index++) {
        final target = selection.targets[index];
        final functionName = target.name.text;
        final fnSeed = functionSeed(baseSeed, index);
        final lowered = lowerFunction(
          target.function,
          operandOrderSeed: fnSeed,
        );
        if (lowered == null) {
          records.add(
            VirtualizationRecord(
              functionName: functionName,
              virtualized: false,
              skipReason: 'outside the supported subset',
            ),
          );
          continue;
        }
        // Fuse `pushConst C; <binop>` into superoperators (M2).
        final program = fuseSuperops(lowered);
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
        final profile = generateIsa(fnSeed);
        final AssembledProgram assembled;
        try {
          assembled = assembleProgram(program, profile);
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
        final interpreter = injector.inject(
          library,
          assembled.stackDepth,
          profile,
        );
        final body = injector.buildReplacementBody(
          interpreter: interpreter,
          words: assembled.words,
          params: target.function.positionalParameters,
          returnsBool: assembled.returnsBool,
        );
        applied.add(
          _AppliedTransform(
            target: target,
            originalBody: target.function.body,
            library: library,
            interpreter: interpreter,
          ),
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
          // Atomic: a verification failure means our own synthesis is wrong, so
          // roll back every mutation and leave the component untouched for the
          // rest of the pipeline (pass_runner keeps running later passes).
          _rollback(applied);
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

/// Records one applied virtualization so it can be undone if validation fails.
final class _AppliedTransform {
  const _AppliedTransform({
    required this.target,
    required this.originalBody,
    required this.library,
    required this.interpreter,
  });

  final Procedure target;
  final Statement? originalBody;
  final Library library;
  final Procedure interpreter;
}

void _rollback(List<_AppliedTransform> applied) {
  for (final t in applied) {
    t.target.function.body = t.originalBody;
    t.originalBody?.parent = t.target.function;
    t.library.procedures.remove(t.interpreter);
  }
}
