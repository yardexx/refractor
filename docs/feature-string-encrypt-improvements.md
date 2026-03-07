# Feature: String Encrypt Pass Improvements

Planned improvements for the string encryption pass.

## Security Tier Definition

These techniques are **Tier 1 (strongly resilient)** under tested compiler modes because they rely on runtime function calls and non-const data flows.

Scope of this guarantee:
- Tested targets: Dart VM JIT (`dart run`) and AOT (`dart compile exe`) on supported CI platforms.
- Tested optimization level: default compiler settings used by project CI/release pipeline.
- Not guaranteed: custom compiler forks, non-default optimizer flags, or source-level hooking of runtime decode calls.

This document intentionally avoids the word "always". Survival claims must be backed by acceptance tests in the "Acceptance Criteria" section.

---

## 1. `StringInterpolation` Handling

**Current gap:** The pass only transforms `StringLiteral` nodes. `StringInterpolation` nodes (e.g., `'Hello $name'`) contain literal parts as `StringLiteral` children, but the parent `StringInterpolation` node is not visited.

**Improvement:** Visit `StringInterpolation` nodes and encrypt each `StringLiteral` part within the interpolation. The interpolation structure is preserved, but literal segments become decode invocations.

**Transformation rule:**
- For every `StringInterpolation`:
  - Replace each literal segment with `StaticInvocation(_obfDecode$, [encoded, key])`.
  - Keep expression segments (`$x`, `${expr}`) unchanged.
  - Preserve original segment ordering exactly.

**Example:**
```dart
// Before:
'Error: $message at line $line'

// After (conceptual):
StringInterpolation([
  StaticInvocation(_obfDecode$, [encoded('Error: '), key1]),
  VariableGet(message),
  StaticInvocation(_obfDecode$, [encoded(' at line '), key2]),
  VariableGet(line),
])
```

---

## 2. Multi-Layer Encoding

**Current state:** Single-byte XOR per UTF-8 byte. Trivially reversible with known key.

**Improvement:** Chain multiple transformations:
1. UTF-8 encode source string (`utf8.encode`)
2. XOR each byte with per-string random key (`key` in `[1,255]`)
3. Reverse byte array
4. Base64 encode (`base64Encode`)

The injected decoder must reverse the chain exactly and preserve non-ASCII correctness:

```dart
@pragma('vm:never-inline')
String _obfDecode$(String encoded, int key) {
  final bytes = base64Decode(encoded);
  final reversed = bytes.reversed.toList(growable: false);
  final decoded = reversed.map((b) => b ^ key).toList(growable: false);
  return utf8.decode(decoded);
}
```

**Key requirements:**
- Use UTF-8 round-trip (`utf8.encode` / `utf8.decode`), not `String.fromCharCodes`, to avoid corruption of multi-byte characters.
- `key=0` is disallowed.

---

## 3. String Array Indirection

**Current state:** Each string is encrypted in-place. String-to-usage association is preserved.

**Improvement:** Extract encrypted strings into a per-library shuffled store and replace each usage with indexed lookup.

**Injection and lifecycle definition:**
- Injection scope: one store per transformed library (not cross-library/global across program).
- Generated members in transformed library:
  - `final List<String> _obfArr$ = <String>[ ...decoded entries... ];`
- Initialization behavior:
  - Eager at library load time (single initialization).
  - Decoding happens once per entry during list initialization.
- Usage rewrite:
  - Original string site becomes `_obfArr$[index]`.
  - Index mapping is stable for a given build artifact.

**Example (conceptual):**
```dart
final _obfArr$ = <String>[
  _obfDecode$('...encrypted string 2...', key2),
  _obfDecode$('...encrypted string 0...', key0),
  _obfDecode$('...encrypted string 1...', key1),
];

print(_obfArr$[1]); // was: print("hello")
```

**Why it helps:**
- Breaks direct string-to-usage association.
- Shuffling removes source-order hints.
- Combined with encryption, raises reversing cost.

---

## 4. `@pragma('vm:never-inline')` on Decode Helper

**Current gap:** `_obfDecode$` may be inlined in AOT/JIT, reducing indirection.

**Improvement:** Add `@pragma('vm:never-inline')` annotation to injected `_obfDecode$`.

In kernel AST:
```dart
Procedure(
  Name('_obfDecode\$'),
  ProcedureKind.Method,
  functionNode,
  annotations: [
    ConstantExpression(
      InstanceConstant(pragmaClass.reference, [], {
        pragmaNameField.fieldReference: StringConstant('vm:never-inline'),
        pragmaOptionsField.fieldReference: NullConstant(),
      }),
    ),
  ],
)
```

**Verification note:** Presence of pragma is required but not sufficient; acceptance tests must confirm helper call sites remain indirect in tested modes.

---

## 5. String Deduplication (Optional)

**Current state:** Identical strings are encrypted separately with different random keys. Better anti-pattern-matching, larger size.

**Configuration surface:**
- Flag: `--string-obf-dedup`
- Type: boolean
- Default: `false`

**Behavior when `false` (default):**
- No deduplication.
- Each occurrence gets independent key and ciphertext.

**Behavior when `true`:**
- Deduplicate by plaintext value within a library.
- Reuse same encoded payload and key for duplicates in that library.
- Preserve functional equivalence; do not change runtime output.

**Trade-off:**
- `false`: stronger resistance to ciphertext pattern matching.
- `true`: reduced binary size.

---

## Acceptance Criteria

A change is complete only if all checks pass:

1. Correctness parity:
- For representative fixtures, transformed program output exactly matches baseline output.

2. Interpolation coverage:
- Literal segments inside `StringInterpolation` are transformed.
- Expression segments remain unmodified.

3. Unicode safety:
- Fixtures containing multi-byte UTF-8 strings (e.g., Czech, emoji, CJK) round-trip correctly.

4. Decode indirection:
- Injected helper is annotated with `@pragma('vm:never-inline')`.
- In tested JIT and AOT artifacts, decode logic is not duplicated at every call site.

5. Array indirection behavior:
- String uses are rewritten to `_obfArr$[index]`.
- `_obfArr$` initializes once per transformed library.

6. Dedup toggle:
- With default config, duplicate plaintexts produce distinct ciphertext entries.
- With `--string-obf-dedup`, duplicate plaintexts collapse per library.

7. Performance and size guardrails:
- Startup/runtime regression from pass is within project-defined threshold.
- Binary size delta is reported for dedup on/off in benchmark fixture.
