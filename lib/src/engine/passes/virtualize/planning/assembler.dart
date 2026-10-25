import 'package:refractor/src/engine/passes/virtualize/planning/isa.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/vm_ir.dart';

/// Assembles a [VmProgram] into a flat `List<int>` bytecode stream under an
/// [IsaProfile]: opcodes are emitted with the profile's per-function numbering
/// and every word (opcode and operand) is position-keyed XOR-encoded. Labels
/// are resolved to word offsets before encoding (positions are unchanged).
final class AssembledProgram {
  const AssembledProgram({
    required this.words,
    required this.argCount,
    required this.returnsBool,
    required this.stackDepth,
  });

  /// Encoded bytecode words (as they ship in the object pool).
  final List<int> words;
  final int argCount;
  final bool returnsBool;
  final int stackDepth;
}

AssembledProgram assembleProgram(VmProgram program, IsaProfile profile) {
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

  // Pass 2: emit plaintext words (permuted opcode numbers, resolved targets).
  final plain = <int>[];
  for (final item in program.items) {
    if (item is! VmInstr) continue;
    plain.add(profile.opcode[item.op]!);
    if (item.op == VmOp.jz || item.op == VmOp.jmp) {
      final target = labelOffsets[item.target];
      if (target == null) {
        throw StackDepthError('unresolved jump target L${item.target}');
      }
      plain.add(target);
    } else if (item.op == VmOp.pushConst || item.op == VmOp.pushArg) {
      plain.add(item.imm ?? 0);
    }
  }

  // Pass 3: position-keyed encode.
  final words = [
    for (var i = 0; i < plain.length; i++) profile.encode(plain[i], i),
  ];

  return AssembledProgram(
    words: words,
    argCount: program.argCount,
    returnsBool: program.returnsBool,
    stackDepth: computeMaxStackDepth(program),
  );
}

/// Hard cap on operand-stack depth. Functions needing more are skipped (left
/// intact) rather than silently truncated.
const int kMaxStackDepth = 1024;

/// Thrown when a program's operand-stack usage cannot be sized safely: paths
/// disagree on depth at a join (malformed lowering), a jump target is missing,
/// or the depth exceeds [kMaxStackDepth]. The pass treats this as "skip this
/// function", never as a silent truncation.
final class StackDepthError implements Exception {
  StackDepthError(this.message);
  final String message;
  @override
  String toString() => 'StackDepthError: $message';
}

/// Computes the exact maximum operand-stack height via control-flow-aware
/// forward propagation (handles `jz`/`jmp` branches, unlike a linear walk).
int computeMaxStackDepth(VmProgram program) {
  final items = program.items;
  final labelIndex = <int, int>{};
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    if (item is VmLabel) labelIndex[item.id] = i;
  }

  final entryDepth = <int, int>{};
  final work = <_DepthState>[const _DepthState(0, 0)];
  var maxDepth = 0;

  int targetIndex(int? labelId, String kind) {
    final index = labelIndex[labelId];
    if (index == null) throw StackDepthError('unresolved $kind target');
    return index;
  }

  while (work.isNotEmpty) {
    final state = work.removeLast();
    var index = state.index;
    var depth = state.depth;
    while (index < items.length) {
      final existing = entryDepth[index];
      if (existing != null) {
        if (existing != depth) {
          throw StackDepthError('inconsistent stack depth at item $index');
        }
        break;
      }
      entryDepth[index] = depth;
      final item = items[index];
      if (item is VmLabel) {
        index += 1;
        continue;
      }
      final instr = item as VmInstr;
      final peak = depth + (_pushesOne(instr.op) ? 1 : 0);
      if (peak > maxDepth) maxDepth = peak;
      if (maxDepth > kMaxStackDepth) {
        throw StackDepthError('stack depth exceeds cap ($kMaxStackDepth)');
      }
      depth += _netEffect(instr.op);
      if (instr.op == VmOp.ret) {
        index = items.length; // terminates this path
      } else if (instr.op == VmOp.jmp) {
        work.add(_DepthState(targetIndex(instr.target, 'jmp'), depth));
        index = items.length; // no fall-through
      } else if (instr.op == VmOp.jz) {
        work.add(_DepthState(targetIndex(instr.target, 'jz'), depth));
        index += 1; // plus fall-through
      } else {
        index += 1;
      }
    }
  }
  return maxDepth < 1 ? 1 : maxDepth;
}

bool _pushesOne(VmOp op) =>
    op == VmOp.pushConst || op == VmOp.pushArg || op == VmOp.dup;

int _netEffect(VmOp op) => switch (op) {
  VmOp.pushConst || VmOp.pushArg || VmOp.dup => 1,
  VmOp.not || VmOp.jmp => 0,
  // all binary ops, comparisons, jz, and ret pop a net of 1
  _ => -1,
};

final class _DepthState {
  const _DepthState(this.index, this.depth);
  final int index;
  final int depth;
}
