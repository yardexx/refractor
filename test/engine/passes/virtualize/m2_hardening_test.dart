import 'dart:math';

import 'package:refractor/src/engine/passes/virtualize/planning/assembler.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/isa.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/lowering/superops.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/reference_interpreter.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/vm_ir.dart';
import 'package:test/test.dart';

// These replicate the MBA identities the injector emits for the hardened
// handlers. They must equal the plain op exactly (which is why the reference
// oracle can stay plain and E6 still holds).
int _mbaAdd(int a, int b) => (a ^ b) + ((a & b) << 1);
int _mbaSub(int a, int b) => (a ^ b) - ((~a & b) << 1);
int _mbaXor(int a, int b) => (~(~a & ~b)) - (a & b); // == (a|b) - (a&b)
int _mbaAnd(int a, int b) => (a | b) - (a ^ b);
int _mbaOr(int a, int b) => (a & b) + (a ^ b);

int _rand64(Random r) => (r.nextInt(1 << 32)) ^ (r.nextInt(1 << 32) << 32);

void main() {
  group('M2 handler hardening', () {
    test('MBA identities equal the plain ops across int64 inputs', () {
      final r = Random(0xA11CE);
      final edges = <int>[
        0,
        1,
        -1,
        2,
        -2,
        0x7FFFFFFFFFFFFFFF,
        -0x8000000000000000,
        0xFFFFFFFF,
      ];
      final inputs = [...edges, for (var i = 0; i < 4000; i++) _rand64(r)];
      for (final a in inputs) {
        for (final b in [...edges, _rand64(r), _rand64(r)]) {
          expect(_mbaAdd(a, b), a + b, reason: 'add($a,$b)');
          expect(_mbaSub(a, b), a - b, reason: 'sub($a,$b)');
          expect(_mbaXor(a, b), a ^ b, reason: 'xor($a,$b)');
          expect(_mbaAnd(a, b), a & b, reason: 'and($a,$b)');
          expect(_mbaOr(a, b), a | b, reason: 'or($a,$b)');
        }
      }
    });

    test(
      'superoperator fusion shrinks the program and preserves semantics',
      () {
        // s*48271 + 9973  (two fusable pushConst+binop pairs)
        final program = VmProgram(
          items: const [
            VmInstr(VmOp.pushArg, imm: 0),
            VmInstr(VmOp.pushConst, imm: 48271),
            VmInstr(VmOp.mul),
            VmInstr(VmOp.pushConst, imm: 9973),
            VmInstr(VmOp.add),
            VmInstr(VmOp.ret),
          ],
          argCount: 1,
          returnsBool: false,
        );
        final fused = fuseSuperops(program);
        final fusedOps = fused.items
            .whereType<VmInstr>()
            .map((i) => i.op)
            .toList();

        expect(fusedOps, contains(VmOp.mulImm));
        expect(fusedOps, contains(VmOp.addImm));
        expect(fusedOps, isNot(contains(VmOp.pushConst)));
        // 6 instrs -> 4 (two pairs fused).
        expect(fusedOps.length, 4);

        int native(int s) => s * 48271 + 9973;
        for (final profile in [IsaProfile.identity(), generateIsa(7)]) {
          final asm = assembleProgram(fused, profile);
          for (final s in const [0, 1, 42, -5, 123456, 999983]) {
            expect(
              runReference(asm.words, [s], profile, stackDepth: asm.stackDepth),
              native(s),
              reason: 's=$s',
            );
          }
        }
      },
    );
  });
}
