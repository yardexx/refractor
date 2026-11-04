# prism

A fixture-driven test harness for Refractor's obfuscation passes.

A prism takes one beam of light and splits it into a spectrum you can inspect
band by band. This package does the same to a Refractor build: it takes one
fixture, builds it once, and decomposes the result into three independently
measurable **bands**.

| Band          | Question it answers                          | How |
|---------------|----------------------------------------------|-----|
| `correctness` | Does the pass survive the compiler?          | Kernel verifier gate + plain-vs-obfuscated behavioral equivalence across targets |
| `resistance`  | Did obfuscation actually happen in the binary? | `strings` denylist/allowlist + pass metric minimums |
| `impact`      | What did it cost?                            | Plain vs obfuscated binary size, size ratio, per-pass metrics |

## Why a separate package

Prism depends on Refractor's internals (the concrete compiler, kernel IO, and
config model, via `package:refractor/testing.dart`) because a harness that
validates the engine has to reach into it. Isolating it in its own
`publish_to: none` package keeps that coupling explicit and out of
Refractor's own dependency surface. The coupling is deliberate: prism is a
canary that should break when internals shift.

Prism is also intentionally independent of `package:test`. Bands return
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
import 'package:prism/prism.dart';
import 'package:test/test.dart';

void main() {
  test('rename fixture', () async {
    final spectrum = await const Prism().analyzeDir('path/to/fixture');
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
