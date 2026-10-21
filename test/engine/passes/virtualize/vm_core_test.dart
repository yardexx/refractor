import 'package:refractor/src/engine/passes/virtualize/planning/assembler.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/reference_interpreter.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/vm_ir.dart';
import 'package:test/test.dart';

// Differential (E6-style) checks of the pure-Dart VM core: the assembler and
// the reference interpreter (the oracle the synthesized kernel interpreter
// mirrors) must agree with the native Dart computation.

int _xformNative(int s) =>
    (((s * 48271 + 0x1234567) ^ 0x5A5A5A5A) & 0xFFFFFF) << 3;

int _branchyNative(int s) => ((s & 1) == 0) ? (s << 5) : (s - 7);

VmProgram _xformProgram() => VmProgram(
  items: const [
    VmInstr(VmOp.pushArg, imm: 0),
    VmInstr(VmOp.pushConst, imm: 48271),
    VmInstr(VmOp.mul),
    VmInstr(VmOp.pushConst, imm: 0x1234567),
    VmInstr(VmOp.add),
    VmInstr(VmOp.pushConst, imm: 0x5A5A5A5A),
    VmInstr(VmOp.xor),
    VmInstr(VmOp.pushConst, imm: 0xFFFFFF),
    VmInstr(VmOp.and),
    VmInstr(VmOp.pushConst, imm: 3),
    VmInstr(VmOp.shl),
    VmInstr(VmOp.ret),
  ],
  argCount: 1,
  returnsBool: false,
);

VmProgram _branchyProgram() {
  const lElse = VmLabel(0);
  const lEnd = VmLabel(1);
  return VmProgram(
    items: const [
      VmInstr(VmOp.pushArg, imm: 0),
      VmInstr(VmOp.pushConst, imm: 1),
      VmInstr(VmOp.and), // s & 1
      VmInstr(VmOp.pushConst, imm: 0),
      VmInstr(VmOp.cmpEq), // (s & 1) == 0
      VmInstr(VmOp.jz, target: 0),
      VmInstr(VmOp.pushArg, imm: 0),
      VmInstr(VmOp.pushConst, imm: 5),
      VmInstr(VmOp.shl), // s << 5
      VmInstr(VmOp.jmp, target: 1),
      lElse,
      VmInstr(VmOp.pushArg, imm: 0),
      VmInstr(VmOp.pushConst, imm: 7),
      VmInstr(VmOp.sub), // s - 7
      lEnd,
      VmInstr(VmOp.ret),
    ],
    argCount: 1,
    returnsBool: false,
  );
}

const _inputs = [
  0,
  1,
  2,
  7,
  42,
  -1,
  -5,
  -7,
  255,
  123456,
  11217657,
  999983,
  0x7FFFFFFFFFFFFFFF,
  -0x8000000000000000,
];

void main() {
  group('VM core differential', () {
    test('straight-line arithmetic program matches native', () {
      final asm = assembleProgram(_xformProgram());
      for (final s in _inputs) {
        expect(
          runReference(asm.words, [s], stackDepth: asm.stackDepth),
          _xformNative(s),
          reason: 'xform(s=$s)',
        );
      }
    });

    test('branching (jz/jmp) program matches native', () {
      final asm = assembleProgram(_branchyProgram());
      for (final s in _inputs) {
        expect(
          runReference(asm.words, [s], stackDepth: asm.stackDepth),
          _branchyNative(s),
          reason: 'branchy(s=$s)',
        );
      }
    });

    test('opcode numbering is dense and unique', () {
      final numbers = kOpcodeNumbers.values.toList()..sort();
      expect(numbers, equals(List.generate(VmOp.values.length, (i) => i)));
    });

    test('exact stack depth is computed (and is branch-aware)', () {
      expect(assembleProgram(_xformProgram()).stackDepth, 2);
      // Both arms of the ternary net +1; the depth is 2, not double-counted.
      expect(assembleProgram(_branchyProgram()).stackDepth, 2);
    });

    test('unresolved jump target is rejected, not silently sized', () {
      final bad = VmProgram(
        items: const [
          VmInstr(VmOp.pushArg, imm: 0),
          VmInstr(VmOp.jz, target: 99), // no such label
          VmInstr(VmOp.ret),
        ],
        argCount: 1,
        returnsBool: false,
      );
      expect(() => assembleProgram(bad), throwsA(isA<StackDepthError>()));
    });
  });
}
