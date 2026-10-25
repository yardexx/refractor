import 'package:refractor/src/engine/passes/virtualize/planning/vm_ir.dart';

/// Peephole pass that fuses `pushConst C; <binop>` into a single superoperator
/// (`<binop>Imm` carrying C). Reduces bytecode length and gives the handler a
/// compound shape (not a liftable single primitive) — the M2 "superoperators"
/// lever.
///
/// Safe because expression lowering emits a const operand immediately before
/// its consuming binary op with no label in between, so no jump can land on the
/// fused op (a jump only targets a label position).
VmProgram fuseSuperops(VmProgram program) {
  final items = program.items;
  final out = <Object>[];
  var i = 0;
  while (i < items.length) {
    final current = items[i];
    if (current is VmInstr &&
        current.op == VmOp.pushConst &&
        i + 1 < items.length) {
      final next = items[i + 1];
      if (next is VmInstr) {
        final superop = superopForBase(next.op);
        if (superop != null) {
          out.add(VmInstr(superop, imm: current.imm));
          i += 2;
          continue;
        }
      }
    }
    out.add(current);
    i++;
  }
  return VmProgram(
    items: out,
    argCount: program.argCount,
    returnsBool: program.returnsBool,
  );
}
