import 'dart:math';

import 'package:refractor/src/engine/passes/virtualize/planning/vm_ir.dart';

/// 48-bit keystream mask: keeps encoded words bounded and keystream math cheap.
const int kKeystreamMask = 0xFFFFFFFFFFFF;

/// A per-function instruction-set + encoding profile (M1).
///
/// Two levers, both validated by the P1–P4 prototypes:
///  - **opcode permutation**: each [VmOp] maps to a per-function byte, so the
///    dispatch numbering learned from one build/function does not transfer.
///  - **position-keyed XOR encoding**: every emitted word (opcode *or* operand)
///    is XORed with `keystream(position)`, so the bytecode is not plaintext in
///    the Dart object pool (E5's finding). Decoding happens per fetch in the
///    interpreter.
///
/// The assembler, the pure-Dart reference interpreter (the E6 oracle), and the
/// synthesized kernel interpreter all consume the same profile, so they stay in
/// lockstep. The decode keys live in the interpreter as constants for M1;
/// environment-derived keys are a later milestone (see docs/02-architecture.md).
final class IsaProfile {
  IsaProfile({required this.opcode, required this.keyA, required this.keyB})
    : _inverse = {for (final e in opcode.entries) e.value: e.key};

  /// Identity profile: canonical numbering, no encoding. Used by tests and as a
  /// fallback; the pass always generates a randomized profile per function.
  factory IsaProfile.identity() =>
      IsaProfile(opcode: Map.of(kOpcodeNumbers), keyA: 0, keyB: 0);

  /// VmOp -> per-function encoded opcode number.
  final Map<VmOp, int> opcode;

  /// Keystream parameters: `keystream(i) = (keyA*(i+1) + keyB) & mask`.
  final int keyA;
  final int keyB;

  final Map<int, VmOp> _inverse;

  int keystream(int position) =>
      (keyA * (position + 1) + keyB) & kKeystreamMask;

  /// Encode a plaintext word for its [position] in the stream.
  int encode(int plainWord, int position) => plainWord ^ keystream(position);

  /// Decode an encoded word fetched from [position].
  int decode(int encodedWord, int position) =>
      encodedWord ^ keystream(position);

  /// The opcode a decoded word denotes (for the reference interpreter).
  VmOp opcodeFor(int decodedWord) {
    final op = _inverse[decodedWord];
    if (op == null) {
      throw StateError('decoded word $decodedWord is not a valid opcode');
    }
    return op;
  }
}

/// Deterministically generates a profile from [seed]. Same seed => same ISA
/// (reproducible builds); the pass mixes a build seed with each function's
/// index so distinct functions get distinct ISAs.
IsaProfile generateIsa(int seed) {
  final rng = Random(seed & 0xFFFFFFFF);
  final used = <int>{};
  final opcode = <VmOp, int>{};
  for (final op in VmOp.values) {
    int value;
    do {
      value = rng.nextInt(256);
    } while (!used.add(value));
    opcode[op] = value;
  }
  int key48() => (rng.nextInt(1 << 24) << 24) | rng.nextInt(1 << 24);
  return IsaProfile(opcode: opcode, keyA: key48(), keyB: key48());
}

/// Mixes a build-level [baseSeed] with a per-function [index] into a stable
/// per-function seed.
int functionSeed(int baseSeed, int index) =>
    (baseSeed ^ (index * 0x9E3779B1) ^ (index << 16)) & 0xFFFFFFFF;
