# Before/After Obfuscation Demo

> **Date:** 2026-03-13
> **App:** `example/lib/main.dart` — stress-test app with classes, mixins, generics, logging, algorithms, unused code
> **Config:** rename (seed: 1337) + string_encrypt (xor_key: 0x5A)

---

## The Example App

The example app (`example/lib/main.dart`) is a 209-line Dart program designed to stress-test the obfuscator with diverse language features:

- **Classes:** `Application<T>`, `AppConfig`, `BaseConfig`, `Logger`, `RandomService`, `Lazy<T>`, `StringTransformer`, `_UnusedClass`
- **Mixins:** `Lifecycle`
- **Enums:** `LogLevel` (debug, info, warn, error)
- **Top-level functions:** `computeComplexValue()`, `dangerousOperation()`
- **String literals:** `'ObfuscatorTest'`, `'alpha'`, `'beta'`, `'gamma'`, `'Starting...'`, `'Experimental features enabled'`, `'Secret: $secret'`
- **Dead code:** `_UnusedClass`, `_unusedFunction`, `_unusedConstants`

---

## Before Obfuscation

### Kernel tree (`refractor inspect`)

Every class, method, field, and parameter is fully readable:

```
package:app/main.dart
  void main(List args)
  int computeComplexValue(int n)
  void dangerousOperation(int value)
  class Application<T extends BaseConfig>
    Application({required T config})
    Future start()
    Future stop()
    final T config
  class BaseConfig
  class AppConfig
    AppConfig({required String appName, required int version, required Map flags})
    final String appName
    final int version
    final Map flags
  class LogLevel
  class Logger
    void debug(String message)
    void info(String message)
    void warn(String message)
    void error(String message)
    void _log(LogLevel level, String message)
    final Logger global
    LogLevel logLevel
  class RandomService
    RandomService({int seed})
    int next()
    final Random _random
  class Lazy<T>
    T value()
    T _cached
    final Function _factory
  class StringTransformer
    List transformAll(Iterable input, Function transformer)
  class _UnusedClass
    String reveal()
    final String secret
```

### Binary strings (`strings app.dill`)

All user-defined identifiers AND string literals are plaintext in the binary:

```
AppConfig
Logger
RandomService
computeComplexValue
dangerousOperation
StringTransformer
_UnusedClass
ObfuscatorTest
alpha
beta
gamma
Starting
Stopping application
Experimental features enabled
Secret: $secret
Lazy value evaluated
```

**An attacker can fully reconstruct the app's architecture, class names, algorithm names, and all hardcoded strings.**

---

## After Obfuscation (rename + string_encrypt)

### Kernel tree (`refractor inspect`)

All user identifiers are replaced with short, meaningless names:

```
package:app/main.dart
  void main(List lK)
  int M(int IT)
  void X(int eZ)
  int _a(int Jg)
  String _obfDecode$(List bytes, int key)
  Map _v
  class J
    J({required TypeParameterType Y})
    Future j()
    Future d()
    final TypeParameterType c
  class Z
  class E
    E({required String i, required int t, required Map C})
    final String V
    final int Q
    final Map U
  class H
    H(int W, String l)
    H p, u, o, T
    List y
  class D
    void w(String r)
    void k(String e)
    void s(String L)
    void f(String B)
    void _S(H Ax, String lW)
    final D K
    H n
  class m
    Future j()
    Future d()
  class g
    g({int rQ})
    int N()
    final Random _A
  class h
    h(Function If)
    TypeParameterType F()
  class O
    List b(Iterable NF, Function Jz)
  class R
    R(String Ap)
    String G()
    final String z
```

### Side-by-side comparison

| Original | Obfuscated | Type |
|----------|-----------|------|
| `Application` | `J` | class |
| `BaseConfig` | `Z` | class |
| `AppConfig` | `E` | class |
| `LogLevel` | `H` | enum |
| `Logger` | `D` | class |
| `Lifecycle` | `m` | mixin |
| `RandomService` | `g` | class |
| `Lazy` | `h` | class |
| `StringTransformer` | `O` | class |
| `_UnusedClass` | `R` | class |
| `computeComplexValue` | `M` | function |
| `dangerousOperation` | `X` | function |
| `_unusedFunction` | `_a` | function |
| `start` | `j` | method |
| `stop` | `d` | method |
| `appName` | `i` | field |
| `logLevel` | `n` | field |
| `_random` | `_A` | field |
| `secret` | `Ap` | field |
| `reveal` | `G` | method |
| `transformAll` | `b` | method |
| `next` | `N` | method |

### Symbol map output

Refractor produces a JSON symbol map (`build/refractor_map.json`) for stack trace deobfuscation:

```json
{
  "j": "start",
  "d": "stop",
  "J": "Application",
  "Z": "BaseConfig",
  "E": "AppConfig",
  "D": "Logger",
  "M": "computeComplexValue",
  "X": "dangerousOperation",
  "R": "_UnusedClass",
  "G": "reveal",
  "Ap": "secret"
}
```

---

## Honest Assessment

### What Refractor protects well

1. **All class names** — `Application`, `Logger`, `RandomService` etc. become single/double-letter identifiers
2. **All method/field names** — `computeComplexValue` -> `M`, `dangerousOperation` -> `X`
3. **Private members** — `_random` -> `_A`, `_log` -> `_S` (privacy prefix preserved)
4. **Local variables and parameters** — `args` -> `lK`, `seed` -> `rQ`
5. **Override consistency** — `start()`/`stop()` from `Lifecycle` mixin get the same obfuscated name (`j`/`d`) across `Application` and the mixin
6. **Dead code** — unused classes/functions are also obfuscated
7. **String literals** (when string_encrypt enabled) — replaced with XOR-encoded byte arrays + `_obfDecode$` calls at runtime

### What remains visible (current limitations)

1. **Source text metadata in .dill** — The kernel binary embeds source text as debug info. Running `strings` on the obfuscated .dill still shows the ORIGINAL source code text:
   ```
   Logger.global.logLevel = LogLevel.debug;
   final app = Application<AppConfig>(
   class RandomService {
   ```
   This is a **major gap**. The AST nodes are renamed, but the embedded source text is not stripped. An attacker running `strings` on the binary sees the original code comments, class names, and structure.

2. **Library URIs** — `package:app/main.dart` is still readable. The library path reveals project structure.

3. **SDK type names** — `Random`, `Future`, `List`, `Map` etc. are SDK types and cannot be renamed.

4. **String interpolation structure** — Even with string_encrypt, interpolated strings like `'Starting ${config.appName}'` become partially encrypted (the template structure may remain).

5. **Const strings** — String encryption correctly skips const contexts (required for correctness), but this means const strings remain readable.

6. **`_obfDecode$` helper** — The injected decryption helper is itself visible, signaling that string encryption was applied.

---

## Key Takeaway

**Refractor successfully transforms the AST** — all identifiers in the kernel tree are renamed, and string literals are encrypted. However, the **embedded source text in .dill files is the biggest remaining gap**. A serious attacker can still read the original code from this metadata. Stripping or obfuscating this source text should be a high-priority feature.

The obfuscation is **additive to Dart's `--obfuscate` flag**, which only renames and doesn't handle strings. Refractor's override family system and string encryption are genuine differentiators. But the source text leak undermines the protection until addressed.