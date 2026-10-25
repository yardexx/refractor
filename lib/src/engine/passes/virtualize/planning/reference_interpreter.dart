import 'package:refractor/src/engine/passes/virtualize/planning/isa.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/vm_ir.dart';

/// Pure-Dart reference interpreter for the encoded bytecode. This is the
/// correctness oracle used by the E6 differential gate.
///
/// Opcode numbering and per-op semantics are specified canonically by `VmOp`
/// in `planning/vm_ir.dart`, under the per-function [IsaProfile] (opcode
/// permutation + position-keyed encoding). This interpreter and the synthesized
/// kernel interpreter (`runtime/interpreter_injector.dart`) are two hand-written
/// mirrors of that spec and MUST stay byte-for-byte equivalent; the VM-core and
/// end-to-end tests guard against drift between them.
int runReference(
  List<int> words,
  List<int> args,
  IsaProfile profile, {
  int stackDepth = 64,
}) {
  final stack = List<int>.filled(stackDepth, 0);
  var sp = 0;
  var pc = 0;
  while (true) {
    final op = profile.opcodeFor(profile.decode(words[pc], pc));
    pc++;
    switch (op) {
      case VmOp.pushConst:
        stack[sp++] = profile.decode(words[pc], pc);
        pc++;
      case VmOp.pushArg:
        stack[sp++] = args[profile.decode(words[pc], pc)];
        pc++;
      case VmOp.add:
        final b = stack[--sp];
        stack[sp - 1] = stack[sp - 1] + b;
      case VmOp.sub:
        final b = stack[--sp];
        stack[sp - 1] = stack[sp - 1] - b;
      case VmOp.mul:
        final b = stack[--sp];
        stack[sp - 1] = stack[sp - 1] * b;
      case VmOp.xor:
        final b = stack[--sp];
        stack[sp - 1] = stack[sp - 1] ^ b;
      case VmOp.and:
        final b = stack[--sp];
        stack[sp - 1] = stack[sp - 1] & b;
      case VmOp.or:
        final b = stack[--sp];
        stack[sp - 1] = stack[sp - 1] | b;
      case VmOp.shl:
        final b = stack[--sp];
        stack[sp - 1] = stack[sp - 1] << b;
      case VmOp.shr:
        final b = stack[--sp];
        stack[sp - 1] = stack[sp - 1] >> b;
      case VmOp.not:
        stack[sp - 1] = ~stack[sp - 1];
      case VmOp.cmpEq:
        final b = stack[--sp];
        stack[sp - 1] = (stack[sp - 1] == b) ? 1 : 0;
      case VmOp.cmpNe:
        final b = stack[--sp];
        stack[sp - 1] = (stack[sp - 1] != b) ? 1 : 0;
      case VmOp.cmpLt:
        final b = stack[--sp];
        stack[sp - 1] = (stack[sp - 1] < b) ? 1 : 0;
      case VmOp.cmpLe:
        final b = stack[--sp];
        stack[sp - 1] = (stack[sp - 1] <= b) ? 1 : 0;
      case VmOp.cmpGt:
        final b = stack[--sp];
        stack[sp - 1] = (stack[sp - 1] > b) ? 1 : 0;
      case VmOp.cmpGe:
        final b = stack[--sp];
        stack[sp - 1] = (stack[sp - 1] >= b) ? 1 : 0;
      case VmOp.dup:
        stack[sp] = stack[sp - 1];
        sp++;
      case VmOp.jz:
        final target = profile.decode(words[pc], pc);
        pc++;
        if (stack[--sp] == 0) pc = target;
      case VmOp.jmp:
        pc = profile.decode(words[pc], pc);
      case VmOp.ret:
        return stack[--sp];
      // Superoperators: pop a; push (a OP imm).
      case VmOp.addImm:
        stack[sp - 1] = stack[sp - 1] + profile.decode(words[pc], pc);
        pc++;
      case VmOp.subImm:
        stack[sp - 1] = stack[sp - 1] - profile.decode(words[pc], pc);
        pc++;
      case VmOp.mulImm:
        stack[sp - 1] = stack[sp - 1] * profile.decode(words[pc], pc);
        pc++;
      case VmOp.xorImm:
        stack[sp - 1] = stack[sp - 1] ^ profile.decode(words[pc], pc);
        pc++;
      case VmOp.andImm:
        stack[sp - 1] = stack[sp - 1] & profile.decode(words[pc], pc);
        pc++;
      case VmOp.orImm:
        stack[sp - 1] = stack[sp - 1] | profile.decode(words[pc], pc);
        pc++;
      case VmOp.shlImm:
        stack[sp - 1] = stack[sp - 1] << profile.decode(words[pc], pc);
        pc++;
      case VmOp.shrImm:
        stack[sp - 1] = stack[sp - 1] >> profile.decode(words[pc], pc);
        pc++;
    }
  }
}
