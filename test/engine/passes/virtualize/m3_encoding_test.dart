import 'package:refractor/src/engine/passes/virtualize/planning/isa.dart';
import 'package:test/test.dart';

void main() {
  group('M3 encoding hardening', () {
    test('keystream is nonlinear (first differences are not constant)', () {
      // M1's affine keystream had constant first differences, so two word-pairs
      // solved keyA/keyB. A nonlinear keystream must not.
      for (final seed in const [1, 2, 3, 42, 0xBEEF, 0xC0FFEE]) {
        final profile = generateIsa(seed);
        final ks = [for (var i = 0; i < 8; i++) profile.keystream(i)];
        final diffs = [for (var i = 1; i < ks.length; i++) ks[i] - ks[i - 1]];
        final affine = diffs.every((d) => d == diffs.first);
        expect(affine, isFalse, reason: 'seed $seed keystream looks affine');
      }
    });

    test('keystream stays within the 48-bit mask', () {
      final profile = generateIsa(7);
      for (var i = 0; i < 64; i++) {
        final k = profile.keystream(i);
        expect(k, inInclusiveRange(0, kKeystreamMask));
      }
    });

    test('identity profile performs no encoding', () {
      final profile = IsaProfile.identity();
      for (var i = 0; i < 8; i++) {
        expect(profile.keystream(i), 0);
        expect(profile.encode(0x1234, i), 0x1234);
        expect(profile.decode(0x1234, i), 0x1234);
      }
    });

    test('encode/decode round-trips under a random profile', () {
      final profile = generateIsa(123);
      for (var i = 0; i < 32; i++) {
        for (final w in const [0, 1, 48271, 0x5A5A5A5A, 0xABC120]) {
          expect(profile.decode(profile.encode(w, i), i), w);
        }
      }
    });
  });
}
