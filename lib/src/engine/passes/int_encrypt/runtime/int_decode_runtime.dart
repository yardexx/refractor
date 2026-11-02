/// Plain-Dart source of the integer-decode runtime helper.
///
/// This is compiled to kernel and injected into the program being obfuscated
/// (see `SourceHelperInjector`), then referenced by the int-encrypt transformer
/// in place of each encoded integer literal.
///
/// The `@pragma('vm:never-inline')` is load-bearing: it stops the AOT compiler
/// from inlining the body and constant-folding `encoded ^ key` back into the
/// original literal, which is what keeps the value out of the binary. It MUST
/// stay the exact inverse of the planner's encoding (`value ^ key`); XOR is its
/// own inverse, so the same expression both encodes and decodes.
library;

/// The top-level function name the injected helper is compiled under. The
/// transformer looks the reparented procedure up in `RuntimeHelpers` by this
/// name; a pass that runs earlier (rename) may change the name itself.
const String intDecodeRuntimeHelperName = 'refractorDecodeInt';

/// The Dart source compiled and injected as the int-decode helper.
const String intDecodeRuntimeSource = '''
@pragma('vm:never-inline')
int refractorDecodeInt(int encoded, int key) => encoded ^ key;

// Required so `dart compile kernel` accepts the helper as an entrypoint. It
// lives in the helper library, which is dropped after `refractorDecodeInt` is
// reparented, so it never reaches the obfuscated program.
void main() {}
''';
