/// Pure-Dart reference interpreter for the flat bytecode. This is the
/// correctness oracle used by the E6 differential gate: its semantics MUST
/// match the synthesized kernel interpreter exactly (same opcode numbering,
/// same 64-bit `int` arithmetic, same stack discipline).
int runReference(List<int> words, List<int> args, {int stackDepth = 64}) {
  final stack = List<int>.filled(stackDepth, 0);
  var sp = 0;
  var pc = 0;
  while (true) {
    final op = words[pc++];
    switch (op) {
      case 0: // pushConst
        stack[sp++] = words[pc++];
      case 1: // pushArg
        stack[sp++] = args[words[pc++]];
      case 2: // add
        final b = stack[--sp];
        stack[sp - 1] = stack[sp - 1] + b;
      case 3: // sub
        final b = stack[--sp];
        stack[sp - 1] = stack[sp - 1] - b;
      case 4: // mul
        final b = stack[--sp];
        stack[sp - 1] = stack[sp - 1] * b;
      case 5: // xor
        final b = stack[--sp];
        stack[sp - 1] = stack[sp - 1] ^ b;
      case 6: // and
        final b = stack[--sp];
        stack[sp - 1] = stack[sp - 1] & b;
      case 7: // or
        final b = stack[--sp];
        stack[sp - 1] = stack[sp - 1] | b;
      case 8: // shl
        final b = stack[--sp];
        stack[sp - 1] = stack[sp - 1] << b;
      case 9: // shr
        final b = stack[--sp];
        stack[sp - 1] = stack[sp - 1] >> b;
      case 10: // not
        stack[sp - 1] = ~stack[sp - 1];
      case 11: // cmpEq
        final b = stack[--sp];
        stack[sp - 1] = (stack[sp - 1] == b) ? 1 : 0;
      case 12: // cmpNe
        final b = stack[--sp];
        stack[sp - 1] = (stack[sp - 1] != b) ? 1 : 0;
      case 13: // cmpLt
        final b = stack[--sp];
        stack[sp - 1] = (stack[sp - 1] < b) ? 1 : 0;
      case 14: // cmpLe
        final b = stack[--sp];
        stack[sp - 1] = (stack[sp - 1] <= b) ? 1 : 0;
      case 15: // cmpGt
        final b = stack[--sp];
        stack[sp - 1] = (stack[sp - 1] > b) ? 1 : 0;
      case 16: // cmpGe
        final b = stack[--sp];
        stack[sp - 1] = (stack[sp - 1] >= b) ? 1 : 0;
      case 17: // dup
        stack[sp] = stack[sp - 1];
        sp++;
      case 18: // jz
        final target = words[pc++];
        if (stack[--sp] == 0) pc = target;
      case 19: // jmp
        pc = words[pc];
      case 20: // ret
        return stack[--sp];
      default:
        throw StateError('Bad opcode $op at pc ${pc - 1}');
    }
  }
}
