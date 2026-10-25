import 'dart:math';

import 'package:refractor/src/engine/passes/virtualize/planning/vm_ir.dart';

/// 48-bit keystream mask: keeps encoded words bounded and keystream math cheap.
const int kKeystreamMask = 0xFFFFFFFFFFFF;

/// A golden-ratio odd constant used to derive a second multiplier from the
/// per-function seed (so one stored seed yields the whole keystream). This
/// tooling only ever runs on the Dart VM, so the JS-rounding lint is moot.
// ignore: avoid_js_rounded_ints
const int kKsGolden = 0x9E3779B97F4A7C15;

/// A per-function instruction-set + encoding profile.
///
/// Two levers, both validated by the P1–P4 prototypes:
///  - **opcode permutation** (M1): each [VmOp] maps to a per-function byte, so
///    the dispatch numbering learned from one build/function does not transfer.
///  - **nonlinear position-keyed encoding** (M3): every emitted word (opcode or
///    operand) is XORed with `keystream(position)`, a *nonlinear* mix of the
///    position and a single per-function [seed] (multiply + xorshift). M1 used
///    an affine `keyA*(i+1)+keyB` that two word-pairs could solve for; the
///    nonlinear mix removes that. It is a pure function of position, so
///    it stays correct across `jz`/`jmp` (unlike execution-state chaining, deferred until
///    control-flow handling — see docs/02-architecture.md).
///
/// The keys are *derived from the single [seed]* inside the keystream, so only
/// one scalar ships per function rather than several (P4's caveat still holds:
/// this relocates the key, it does not hide it). The assembler, the reference
/// interpreter, and the synthesized kernel interpreter all compute the
/// identical keystream, so they stay in lockstep.
final class IsaProfile {
  IsaProfile({required this.opcode, required this.seed, this.encoded = true})
    : _inverse = {for (final e in opcode.entries) e.value: e.key};

  /// Identity profile: canonical numbering, no encoding. Used by tests and as a
  /// fallback; the pass always generates a randomized, encoded profile.
  factory IsaProfile.identity() =>
      IsaProfile(opcode: Map.of(kOpcodeNumbers), seed: 0, encoded: false);

  /// VmOp -> per-function encoded opcode number.
  final Map<VmOp, int> opcode;

  /// Per-function master key; the keystream derives its multipliers from it.
  final int seed;

  /// Whether words are encoded (false for the identity profile).
  final bool encoded;

  final Map<int, VmOp> _inverse;

  /// Nonlinear keystream for a stream [position]. Mirrored bit-for-bit by the
  /// synthesized `_ks$N` interpreter helper.
  int keystream(int position) {
    if (!encoded) return 0;
    var h = (position + 1) ^ seed;
    h = h * (seed | 1);
    h = h ^ (h >>> 29);
    h = h * ((seed ^ kKsGolden) | 1);
    h = h ^ (h >>> 32);
    return h & kKeystreamMask;
  }

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
  final master = (rng.nextInt(1 << 32) << 32) | rng.nextInt(1 << 32);
  return IsaProfile(opcode: opcode, seed: master);
}

/// Mixes a build-level [baseSeed] with a per-function [index] into a stable
/// per-function seed.
int functionSeed(int baseSeed, int index) =>
    (baseSeed ^ (index * 0x9E3779B1) ^ (index << 16)) & 0xFFFFFFFF;
