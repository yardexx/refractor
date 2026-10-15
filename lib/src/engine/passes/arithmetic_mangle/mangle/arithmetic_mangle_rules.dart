import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/builder/kernel_builder.dart';

/// A fresh reference to a previously bound operand. Called once per occurrence,
/// so the operand is evaluated once (by the binding) and merely read here.
typedef OperandRef = Expression Function();

/// `a + b` as `(a ^ b) + ((a & b) << 1)` — the carry/sum identity, equal to
/// `a + b` for two's-complement integers.
Expression mangleAddition(
  KernelBuilder b,
  OperandRef a,
  OperandRef other,
  int k,
) {
  return b.add(
    b.xor(a(), other()),
    b.shl(b.bitAnd(a(), other()), b.intLit(1)),
  );
}

/// `a * b` as `a * (b + k) - a * k` — distributes the multiply over a random
/// constant and cancels it, so the direct multiply is no longer visible. Equal
/// to `a * b` for every `k` (including under wrap-around).
Expression mangleMultiplication(
  KernelBuilder b,
  OperandRef a,
  OperandRef other,
  int k,
) {
  return b.sub(
    b.mul(a(), b.add(other(), b.intLit(k))),
    b.mul(a(), b.intLit(k)),
  );
}
