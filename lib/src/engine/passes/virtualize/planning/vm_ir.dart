/// Virtual-machine intermediate representation for the virtualization pass.
///
/// M0 scope: a straight-line / simple-branch stack machine over 64-bit [int]
/// values (bools are represented as 0/1). The same opcode numbering defined
/// here is shared by the assembler, the reference interpreter (the correctness
/// oracle), and the synthesized kernel interpreter, so all three agree.
library;

/// Stack-machine operations. Operands are taken from / pushed to a value stack.
enum VmOp {
  /// Push an immediate constant (carries one immediate: the value).
  pushConst,

  /// Push the Nth argument (carries one immediate: the argument index).
  pushArg,

  // Binary arithmetic/bitwise: pop b, pop a, push (a OP b).
  add,
  sub,
  mul,
  xor,
  and,
  or,
  shl,
  shr,

  /// Unary bitwise NOT: pop a, push ~a.
  not,

  // Comparisons: pop b, pop a, push (a CMP b) ? 1 : 0.
  cmpEq,
  cmpNe,
  cmpLt,
  cmpLe,
  cmpGt,
  cmpGe,

  /// Duplicate the top of stack.
  dup,

  /// Pop v; if v == 0 jump to the immediate target (word offset).
  jz,

  /// Unconditional jump to the immediate target (word offset).
  jmp,

  /// Return the top of stack.
  ret,
}

/// Which opcodes carry a single trailing immediate word in the flat bytecode.
bool opHasImmediate(VmOp op) =>
    op == VmOp.pushConst ||
    op == VmOp.pushArg ||
    op == VmOp.jz ||
    op == VmOp.jmp;

/// Canonical fixed opcode numbering for M0 (diversity/randomization is M1).
/// Kept dense and stable so the assembler and both interpreters agree.
const Map<VmOp, int> kOpcodeNumbers = <VmOp, int>{
  VmOp.pushConst: 0,
  VmOp.pushArg: 1,
  VmOp.add: 2,
  VmOp.sub: 3,
  VmOp.mul: 4,
  VmOp.xor: 5,
  VmOp.and: 6,
  VmOp.or: 7,
  VmOp.shl: 8,
  VmOp.shr: 9,
  VmOp.not: 10,
  VmOp.cmpEq: 11,
  VmOp.cmpNe: 12,
  VmOp.cmpLt: 13,
  VmOp.cmpLe: 14,
  VmOp.cmpGt: 15,
  VmOp.cmpGe: 16,
  VmOp.dup: 17,
  VmOp.jz: 18,
  VmOp.jmp: 19,
  VmOp.ret: 20,
};

/// A single IR instruction. [target] is a label id for jumps (resolved to a
/// word offset by the assembler); [imm] is the immediate for pushConst/pushArg.
final class VmInstr {
  const VmInstr(this.op, {this.imm, this.target});

  final VmOp op;
  final int? imm;
  final int? target;

  @override
  String toString() {
    final arg = imm != null
        ? ' $imm'
        : target != null
        ? ' ->L$target'
        : '';
    return '${op.name}$arg';
  }
}

/// A label marker in the instruction stream (resolved to an offset at
/// assembly time).
final class VmLabel {
  const VmLabel(this.id);
  final int id;
}

/// Lowered program for one function: an ordered mix of instructions and labels.
final class VmProgram {
  VmProgram({
    required this.items,
    required this.argCount,
    required this.returnsBool,
  });

  /// Each item is either a [VmInstr] or a [VmLabel].
  final List<Object> items;
  final int argCount;

  /// Whether the original function returned bool (so the call site unwraps
  /// `result != 0`) versus int (used directly).
  final bool returnsBool;
}
