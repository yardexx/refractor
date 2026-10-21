import 'package:refractor/src/engine/passes/virtualize/planning/vm_ir.dart';

/// Assembles a [VmProgram] into a flat `List<int>` bytecode stream using the
/// canonical M0 opcode numbering. Labels are resolved to word offsets.
///
/// M0 emits plaintext bytecode; per-build encoding (chained keystream) is M1.
final class AssembledProgram {
  const AssembledProgram({
    required this.words,
    required this.argCount,
    required this.returnsBool,
    required this.stackDepth,
  });

  final List<int> words;
  final int argCount;
  final bool returnsBool;
  final int stackDepth;
}

AssembledProgram assembleProgram(VmProgram program) {
  // Pass 1: compute the word offset of each label.
  final labelOffsets = <int, int>{};
  var offset = 0;
  for (final item in program.items) {
    if (item is VmLabel) {
      labelOffsets[item.id] = offset;
    } else if (item is VmInstr) {
      offset += opHasImmediate(item.op) ? 2 : 1;
    }
  }

  // Pass 2: emit words, resolving jump targets.
  final words = <int>[];
  for (final item in program.items) {
    if (item is! VmInstr) continue;
    words.add(kOpcodeNumbers[item.op]!);
    if (item.op == VmOp.jz || item.op == VmOp.jmp) {
      final target = labelOffsets[item.target];
      if (target == null) {
        throw StateError('Unresolved jump target L${item.target}');
      }
      words.add(target);
    } else if (item.op == VmOp.pushConst) {
      words.add(item.imm ?? 0);
    } else if (item.op == VmOp.pushArg) {
      words.add(item.imm ?? 0);
    }
  }

  return AssembledProgram(
    words: words,
    argCount: program.argCount,
    returnsBool: program.returnsBool,
    stackDepth: _estimateStackDepth(program),
  );
}

/// Conservative operand-stack depth estimate (upper bound) for sizing the
/// interpreter's stack. Walks the linear item stream tracking net push/pop.
int _estimateStackDepth(VmProgram program) {
  var depth = 0;
  var max = 0;
  for (final item in program.items) {
    if (item is! VmInstr) continue;
    switch (item.op) {
      case VmOp.pushConst:
      case VmOp.pushArg:
      case VmOp.dup:
        depth += 1;
      case VmOp.add:
      case VmOp.sub:
      case VmOp.mul:
      case VmOp.xor:
      case VmOp.and:
      case VmOp.or:
      case VmOp.shl:
      case VmOp.shr:
      case VmOp.cmpEq:
      case VmOp.cmpNe:
      case VmOp.cmpLt:
      case VmOp.cmpLe:
      case VmOp.cmpGt:
      case VmOp.cmpGe:
        depth -= 1; // pop 2, push 1
      case VmOp.jz:
      case VmOp.ret:
        depth -= 1;
      case VmOp.not:
      case VmOp.jmp:
        break; // net 0
    }
    if (depth > max) max = depth;
  }
  // Pad for safety; branches make the linear walk approximate.
  return (max + 4).clamp(8, 256);
}
