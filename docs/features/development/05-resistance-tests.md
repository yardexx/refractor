# Obfuscation Resistance Tests

**Status:** active
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** `v0.2.0+`
**Related:** [../../roadmap/v0.2.0.md](../../roadmap/v0.2.0.md), [../../roadmap/v0.2-overview.md](../../roadmap/v0.2-overview.md)

## Goal

Verify obfuscation effectiveness against real reverse-engineering tools. The
question is not only whether the AST changed, but whether an attacker can still
recover meaningful names and strings from the shipped artifact.

## Scope

Included:

- lightweight resistance testing with `strings`
- heavier optional resistance testing with Blutter
- explicit allowlists, denylists, and fixture expectations

Not included:

- claiming complete reverse-engineering resistance
- replacing correctness-focused unit and E2E tests

## Acceptance Criteria

- at least one practical resistance test is automated and actionable
- plaintext leakage checks are explicit and reproducible
- test output distinguishes real leaks from expected SDK/runtime strings

## Test Plan

- Tier 1 automated `strings` checks
- Tier 2 optional/manual Blutter verification
- representative fixtures with known identifiers and strings

## Open Questions

- should heavy resistance tests live in normal CI or a separate scheduled path?
- what is the minimum platform matrix we want for `strings`-based coverage?

## Overview

Two tiers of resistance testing:

| Tier | Tool | Runs in CI? | Dependencies | What it verifies |
|------|------|-------------|-------------|------------------|
| 1 | `strings` | Yes | None (built-in) | No plaintext names/strings leak into native binary |
| 2 | Blutter | Optional / manual | Android SDK, Flutter, Python, C++ toolchain | No symbols recovered from ARM64 AOT snapshot |

Tier 1 ships first — zero dependencies, runs everywhere, catches the most common leaks.
Tier 2 is for periodic manual verification or a heavy CI job.

---

## Tier 1: `strings` Resistance Test

### What it tests

The `strings` command extracts all printable character sequences from a binary. If original class names, method names, or string literals appear in the `strings` output of an obfuscated binary, the obfuscation has failed to protect them.

### Test design

```
test/security/
  strings_resistance_test.dart
```

```
1. Write a test Dart program with known identifiers and strings
2. Compile to .dill → obfuscate (rename + string_encrypt) → compile to native exe
3. Run `strings` on the exe
4. Assert: NONE of the original identifiers or string literals appear in the output
5. Assert: obfuscated names DO appear (sanity check that the binary is valid)
```

### What to check

**Must NOT appear** (obfuscation failures):
```
# Original class/method/field names
Application
AppConfig
computeComplexValue
dangerousOperation
StringTransformer
RandomService
logLevel

# Original string literals (when string_encrypt enabled)
ObfuscatorTest
Starting
Stopping application
Experimental features enabled
Secret:
Lazy value evaluated
```

**May appear** (not failures — these are SDK/framework names):
```
# Dart SDK types (cannot be renamed)
String
List
Map
Future
Random
int
bool

# Dart runtime internals
_Closure
_GrowableList
dart:core
dart:async
```

**Should appear** (sanity checks — proves binary is valid):
```
# Obfuscated names (short, meaningless)
# At least some single/double-letter identifiers from the rename pass
```

### Platform considerations

- `strings` works on all platforms (macOS, Linux, Windows via GNU tools)
- On macOS: `/usr/bin/strings`
- On Linux: `/usr/bin/strings`
- On Windows: needs GNU `strings.exe` or use `findstr` equivalent
- The test compiles to `exe` target, so it tests the final native binary

### Limitations

- `strings` finds exact byte sequences. It won't find strings that are split across segments or compressed.
- XOR-encrypted strings will NOT appear in `strings` output (this is the goal).
- Const strings that can't be encrypted WILL appear — the test should have a known allowlist for these.
- Source text metadata in `.dill` is stripped during `dart compile exe`, so this only matters for the `kernel` target.

---

## Tier 2: Blutter Resistance Test

### What Blutter is

Blutter (2,170 stars, actively maintained) is the primary Flutter reverse engineering tool. It parses `libapp.so` (ARM64 Android) using version-matched Dart VM headers to extract:

- Full class hierarchy (names, inheritance, interfaces, mixins)
- All method signatures (names, parameter types, return types)
- All field declarations
- Object pool contents (all string constants, numeric constants, objects)
- Annotated ARM64 disassembly with resolved call targets

### What Blutter always recovers (regardless of obfuscation)

| Data | Recoverable? | Why |
|------|-------------|-----|
| String literals | Always | Stored in object pool as plaintext |
| Numeric constants | Always | Stored in object pool |
| SDK/framework names | Always | Not obfuscated by Flutter or Refractor |
| Class hierarchy structure | Always | Metadata preserved in snapshot |
| Function signatures (types) | Always | Type info preserved |
| Code structure / control flow | Always | ARM64 instructions unchanged |

### What obfuscation hides from Blutter

| Data | Hidden? | Notes |
|------|---------|-------|
| App class names | Yes (rename) | Become short random identifiers |
| App method names | Yes (rename) | Become short random identifiers |
| App field names | Yes (rename) | Become short random identifiers |
| Library URIs | Partially | Paths obfuscated but scheme preserved |
| String literals | Yes (string_encrypt) | XOR-encoded, not in object pool as plaintext |
| Control flow | No (until CFF ships) | Logic is unchanged |

### Blutter output files to parse

Blutter produces several output files. The most useful for automated testing:

**1. `pp.txt` — Object Pool Dump**

Each line: `[pp+0x{offset}] {type}: {value}`

```
[pp+0xe918] String: "IV_SALT"
[pp+0xe930] Obj!AESMode@57d1c1 : { mode: 0x0, name: "cbc" }
[pp+0x1234] IMM: 0x42
```

**Test**: grep for original string literals. None should appear if string_encrypt is enabled.

**2. `asm/*.dart` — Disassembled Code**

One file per library, containing class and method declarations with annotated disassembly:

```
class MyClassName extends SuperClass implements InterfaceA {
  Field _myField@123456;

  static void myMethod(String arg1, int arg2) {
    // ** addr: 0x12345, size: 0x80
    // 0x12345: mov x0, x1
    // 0x12349: ldr x2, [x27, #0x1234]  ; String: "hello"
    // 0x1234d: bl #0x5678  ; [dart:core] print::call -> void
  }
}
```

**Test**: grep for original class/method names in asm files. None should appear if rename is enabled.

**3. `ida_script/addNames.py` — Complete Symbol List**

Contains every recovered symbol:

```python
idaapi.set_name(0x12345, "mylib_MyClass::myMethod_12345")
```

**Test**: parse this file for a complete list of recovered symbols. None should match original names.

### Test design

```
test/security/
  blutter_resistance_test.dart    # @Tags(['security', 'slow'])
```

```
1. Build a Flutter Android APK with known identifiers
   - flutter build apk --release --target-platform android-arm64
   - Apply Refractor obfuscation on the .dill before final compilation

2. Extract ARM64 libs from APK
   - unzip app-release.apk lib/arm64-v8a/* -d /tmp/apk

3. Run Blutter
   - python3 blutter.py /tmp/apk/lib/arm64-v8a /tmp/blutter-out

4. Parse output and assert:
   a. pp.txt: no original string literals found
   b. asm/*.dart: no original class/method names in declarations
   c. ida_script/addNames.py: no original names in symbol list

5. Sanity checks:
   a. Blutter completed successfully (exit code 0)
   b. asm/ directory is non-empty (binary was parseable)
   c. SDK names ARE present (proves Blutter ran correctly)
```

### Infrastructure requirements

Blutter requires heavy dependencies. Two options:

**Option A: Skip in CI, run manually**

Tag with `@Tags(['security'])` and exclude from default `dart test`:

```yaml
# dart_test.yaml
tags:
  security:
    skip: "Requires Blutter + Android SDK. Run manually with: dart test -t security"
```

Run periodically during development:
```bash
dart test -t security
```

**Option B: Dedicated CI job**

GitHub Actions with Android SDK + Flutter + Python + C++ toolchain. Runs on release branches only:

```yaml
# .github/workflows/security-tests.yml
on:
  push:
    branches: [release/*]
jobs:
  blutter-resistance:
    runs-on: ubuntu-latest
    steps:
      - uses: subosito/flutter-action@v2
      - uses: actions/setup-python@v5
      - run: sudo apt-get install gcc-13 cmake ninja-build libcapstone-dev libicu-dev
      - run: pip install pyelftools requests
      - run: git clone https://github.com/worawit/blutter.git
      - run: dart test -t security
```

### Critical limitation

**Blutter only works on Android ARM64 (`libapp.so`)**. It cannot analyze:
- Dart native executables (`dart compile exe`)
- macOS/Linux/Windows Flutter desktop builds
- iOS binaries
- Raw `.dill` files

This means the Blutter test requires a **Flutter Android build**, not just a Dart compile. This is a fundamentally different pipeline than the `strings` test.

---

## Implementation Priority

### Phase 1: `strings` resistance test (ship now)

- Zero dependencies beyond `dart compile exe`
- Runs on all platforms
- Catches the most visible leaks (plaintext names and strings in native binary)
- Extends the existing E2E test infrastructure
- **Effort: S (half day)**

### Phase 2: Blutter resistance test (ship with CFF)

- Requires Flutter + Android SDK + Python + C++ toolchain
- Only runs on Linux (CI) or manually
- Most valuable AFTER control flow flattening ships — verifies structural transforms defeat Blutter's analysis
- **Effort: M (2-3 days including CI setup)**

---

## Test Fixture Design

Both tiers use the same test program — a compact Dart program with diverse, distinctive identifiers that are easy to grep for:

```dart
// Identifiers chosen to be unique and greppable (won't match SDK names)
class SecretAlgorithm {
  final String apiEndpoint;
  SecretAlgorithm(this.apiEndpoint);
  int computeProfitMargin(int revenue, int cost) => revenue - cost;
}

class EncryptionService {
  String encryptPayload(String data) => data.split('').reversed.join();
}

void processConfidentialData() {
  final algo = SecretAlgorithm('https://api.internal.example.com/v2');
  final margin = algo.computeProfitMargin(1000, 400);
  print('Result: $margin');
}
```

**Forbidden strings** (must not appear in obfuscated binary):
- `SecretAlgorithm`, `EncryptionService`, `processConfidentialData`
- `apiEndpoint`, `computeProfitMargin`, `encryptPayload`
- `https://api.internal.example.com/v2` (when string_encrypt enabled)

**Allowed strings** (will appear, not failures):
- `Result:` — may survive as const or interpolation template
- SDK type names (`String`, `int`, `List`)
- Dart runtime internals

---

## Future: Resistance Scoring

Once both tiers are running, add a quantitative score:

```
Protection Report:
  strings resistance:  98% (2/142 strings leaked — both const)
  blutter resistance:  100% (0/47 app symbols recovered)
  overall:             99%
```

This feeds into the DevTools extension protection score dashboard.
