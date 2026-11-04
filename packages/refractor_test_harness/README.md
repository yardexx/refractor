# refractor_test_harness

The internal, fixture-driven harness for **developing** Refractor's
obfuscation passes. It owns the build (compile → obfuscate → compile) and
decomposes the result into three independently measurable **bands**.

> This is the engine-coupled, SDK-pinned *developer* tool. It is distinct from
> [`prism`](../prism), the source-free, customer-facing verifier that inspects
> an already-built artifact without rebuilding it.

| Band          | Question it answers                          | How |
|---------------|----------------------------------------------|-----|
| `correctness` | Does the pass survive the compiler?          | Kernel verifier gate + plain-vs-obfuscated behavioral equivalence across targets |
| `resistance`  | Did obfuscation actually happen in the binary? | `strings` denylist/allowlist + pass metric minimums |
| `impact`      | What did it cost?                            | Plain vs obfuscated binary size, size ratio, per-pass metrics |

## Why a separate package

The harness depends on Refractor's internals (the concrete compiler, kernel
IO, and config model, via `package:refractor/testing.dart`) because a tool
that validates the engine has to reach into it. Isolating it in its own
`publish_to: none` package keeps that coupling explicit and out of
Refractor's own dependency surface. The coupling is deliberate: the harness is
a canary that should break when internals shift.

The harness is also intentionally independent of `package:test`. Bands return
structured `Spectrum` data; the calling test decides how to assert. The same
data can drive a CI summary or a standalone script.

## Fixture layout

Each scenario is one directory:

```text
<fixture>/
  main.dart           # the program under obfuscation
  refractor.yaml      # the passes to apply
  expectations.yaml   # the contract for all three bands
```

`expectations.yaml` is a superset of the original resistance-only schema, so
existing fixtures keep working:

```yaml
behavior:
  targets: [exe, aot, jit]     # correctness runs equivalence on each
  equivalent_to_plain: true
  verify_kernel: true          # run the kernel verifier gate

resistance:
  denylist: [SecretAlgorithm]  # must NOT appear in the binary
  allowlist: [VISIBLE_MARKER]  # must still appear
  required_metrics:
    string_encrypt.strings_encrypted: 1

impact:
  max_size_ratio: 1.15         # optional; the ratio is always reported
```

## Usage

```dart
import 'package:refractor_test_harness/refractor_test_harness.dart';
import 'package:test/test.dart';

void main() {
  test('rename fixture', () async {
    final spectrum = await const Harness().analyzeDir('path/to/fixture');
    printOnFailure(spectrum.describe());
    expect(spectrum.ok, isTrue, reason: spectrum.describe());
  });
}
```

`spectrum.describe()` renders every band's readings and failures — so the
numbers (binary sizes, rename/encrypt counts) are visible even on a green run.

## Status

Report-first by design. The impact band currently *reports* size and metrics
rather than enforcing baselines; `max_size_ratio` is the only optional
assertion. Regression baselines are deferred deliberately — they are brittle
across SDK bumps and are worth adding only once the raw numbers are trusted.
