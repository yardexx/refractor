# E1 Gate Experiment — Findings

**Experiment:** E1 from `docs/01-research.md` §10 — "Minimal injected interpreter survives AOT."
**Question:** Does a synthesized bytecode interpreter survive Dart AOT compilation in a recognizable, non-simplified form, or does the AOT optimizer collapse it back toward the original arithmetic?
**Date:** 2026-10-17
**Verdict: ✅ E1 GATE PASSES.** The interpreter survives AOT fully intact and recognizable; AOT performed **zero** partial-evaluation of the handlers against the constant bytecode. Virtualization is viable to pursue (subject to E2–E6).

> Scope note: no Refractor code was touched. The experiment ran in a scratch dir on branch `claude/elated-montalcini-ce8a06`; the raw disassembly artifacts (`E1-artifacts/`) live in that session's notes folder, not in this checkout.

---

## 1. Toolchain (exact versions)

- **Dart SDK 3.11.3 (stable)** — exactly the Refractor pin. `(Tue Mar 17 01:06:16 2026 -0700) on "macos_arm64"`.
- **Flutter 3.41.5** (stable, engine `c1db59d880`), bundling the same Dart 3.11.3.
- `gen_snapshot` from the Flutter/Dart cache: `~/fvm/versions/3.41.5/bin/cache/dart-sdk/bin/utils/gen_snapshot` (this is the **same AOT backend** Flutter uses for Android/iOS release).
- Host: macOS (Darwin 25.5.0), Apple arm64.
- Disassembly: GNU binutils `objdump` (`/opt/homebrew/opt/binutils/bin/objdump`) + `llvm-objdump`.

**RE tooling note:** No deep RE provider was available locally — REA's Hopper/Ghidra/IDA providers are all unconfigured (`rea doctor` → Hopper not found; Ghidra needs `GHIDRA_INSTALL_DIR` + JDK21; IDA not registered), and **Blutter is not installed**. This did not block the experiment: the decisive evidence comes from the AOT compiler's own labeled assembly output (`gen_snapshot --snapshot_kind=app-aot-assembly`), which emits the real, optimized native ARM64 for every function with its symbol — authoritative and independent of any third-party disassembler.

---

## 2. Method

A ~30-byte, 13-opcode switch-loop **stack VM** was hand-written in Dart (`vm.dart`), executing a non-trivial branching integer "license" transform, alongside an identical **control** written as plain arithmetic:

```
f(x):  t = x*48271 + 9973;  t ^= 0x5A5A5A5A;  t &= 0x00FFFFFF;
       if ((t & 1) == 0) t <<= 5; else t -= 7;  return t;
```

Opcodes: `PUSH_CONST, PUSH_ARG, ADD, SUB, MUL, XOR, AND, SHL, DUP, CMP_EQ, JZ, JMP, RET`.
The program is encoded as a **`const List<int>` bytecode array** — deliberately giving the optimizer the *best possible* chance to partial-evaluate the interpreter over known data (the stringent form of the test). The interpreter is marked `@pragma('vm:never-inline')` — exactly as Refractor's string-encrypt pass marks its injected helper.

- `plainLicense(x)` — control (arithmetic in the clear).
- `vmLicense(x)` → `interp(kBytecode, x)` — the virtualized path.
- Input `x` comes from **argv at runtime**, so the whole computation cannot be constant-folded away.

**Equivalence check (mini-E6):** VM ≡ control verified in JIT across 16 inputs covering both branches (even/odd) and negatives — all `match=true`. The compiled AOT exe also prints `match=true`.

### Commands

```bash
# 1. Verify semantics (JIT)
dart run vm.dart <x>               # -> plain=.. vm=.. match=true

# 2a. AOT exe (same gen_snapshot pipeline as Flutter), + debug symbols
dart compile exe vm.dart -o vm.exe --save-debugging-info=vm.debug.so
./vm.exe 42                        # -> plain=4541482 vm=4541482 match=true

# 2b. Authoritative labeled AOT assembly (the primary evidence)
dartaotruntime <sdk>/bin/snapshots/gen_kernel_aot.dart.snapshot \
    --platform <sdk>/lib/_internal/vm_platform_strong.dill \
    --aot --tfa -o vm.aot.dill vm.dart
gen_snapshot --snapshot_kind=app-aot-assembly --assembly=vm.S vm.aot.dill

# 3. Real Flutter release artifact
flutter build apk --release --target-platform android-arm64 --split-debug-info=symbols
```

---

## 3. Results

### 3.1 Symbol table — the interpreter survives as its own function

From `--save-debugging-info` (`llvm-objdump -t vm.debug.so`):

| symbol | size | meaning |
|---|---|---|
| `vmLicense` | **44 bytes** | tiny thunk → calls `interp` |
| `_interp` | **~1988 bytes** | the interpreter, fully present |
| `plainLicense` | ~100 bytes | the control |

`vm:never-inline` **held**: `_interp` is a standalone function; it was **not** inlined into `vmLicense`, and `vmLicense` did **not** absorb the arithmetic. Had AOT collapsed the VM, `vmLicense` would be ~arithmetic-sized and `_interp` dead/absent. Instead `_interp` is large and live.

### 3.2 `vmLicense` is a pure dispatch thunk (no arithmetic)

```asm
vmLicense:
  stp x29,x30,[x15,#-16]! ; mov x29,x15      ; prologue
  ldr x16,[x26,#72] ; cmp x15,x16 ; b.ls ... ; stack-limit check
  bl  _interp                                 ; <-- just calls the interpreter
  ldp x29,x30,[x15],#16 ; ret                 ; epilogue
```
No `48271`, no `9973`, no `0x5A5A5A5A`. The algorithm is **not** reachable from `vmLicense`'s code.

### 3.3 `plainLicense` (control) exposes the entire algorithm in the clear

```asm
plainLicense:
  ubfx x1,x1,#0,#32
  mov  x16,#0xbc8f          // #48271
  mul  x2,x1,x16
  mov  x17,#0x26f5          // #9973
  add  w1,w2,w17
  mov  x16,#0x5a5a ; movk x16,#0x5a5a,lsl#16   // 0x5A5A5A5A
  eor  w2,w1,w16
  and  w1,w2,#0xffffff
  tbnz w2,#0, <else>        // if ((t&1)!=0)
  lsl  x3,x2,#5             // then: t<<5
  ... sub x2,x1,#7          // else: t-7
  ret
```
This is the attacker's dream: the full predicate (constants, XOR mask, parity branch, shift) readable in ~15 instructions. **This is exactly what virtualization must hide — and the VM path does.**

### 3.4 `_interp` is a textbook interpreter loop — handlers NOT folded

The 498-instruction body (full disasm: `E1-artifacts/interp.disasm.txt`) contains, intact:

- **Stack allocation**: `List<int>.filled(32,0)` → an alloc call + a zero-init loop bounded by `cmp x3,#0x20` (32).
- **Bytecode load from the object pool**: `ldr x4,[x27,#22240]` materializes the `kBytecode` const `List<int>` (x27 = pool pointer). The bytecode is a real heap object referenced at runtime, not inlined code.
- **The fetch–decode loop** (`while(true)`): per iteration it bounds-checks `pc` against **`#0x1e` = 30** (the bytecode length), loads `code[pc]` (`ldur x8,[x16,#23]`), untags the smi (`asr x5,x8,#1`), then dispatches.
- **Dispatch**: a balanced **binary-search decision tree over the opcode** — `cmp x5,#6; b.gt` / `cmp #3; b.gt` / `cmp #1; b.gt` / `cmp #0; b.gt` / `cbnz` — i.e. the `switch` lowered to a comparison tree branching to handler groups (`0x138, 0x188, 0x2c8, 0x4ac, 0x6e4`). This is the unmistakable structural signature of a VM.
- **Generic handlers** operating on *runtime-loaded* stack slots, e.g. the SUB handler: `asr x11,x9,#1 ; asr x9,x10,#1 ; sub x10,x9,x11` (untag two stack values, subtract). MUL/ADD/XOR/AND/SHL appear likewise as generic register ops; operands come from the stack/bytecode, never as inlined literals.
- **Safety machinery retained**: **43 `bl` calls** to runtime stubs (RangeError throwers, int boxing, allocation) — AOT did *not* prove away the array bounds checks despite the constant bytecode.

**Critically:** a grep of the entire `_interp` body for the source constants (`48271`/`0xbc8f`, `9973`/`0x26f5`, `0x5a5a5a5a`, the `movk #0x5a5a` pattern) finds **none**. They appear **only** in `plainLicense`. The AOT optimizer did **not** partial-evaluate / specialize the interpreter against the known bytecode, did **not** unroll the dispatch loop, and did **not** reconstruct the arithmetic. The handlers stayed generic and data-driven.

### 3.5 Is the bytecode a visible data array?

It is present as a **`const List<int>` in the serialized isolate snapshot** (loaded via `ldr x4,[x27,#22240]`), **reconstructable by a Dart-snapshot-aware tool (Blutter)**. It is **not** recoverable by a naive hex scan of the file: an alignment-independent byte search of `vm.exe` for the element values (raw, and smi-encoded `value<<1`, 4- and 8-byte) found **none** of `48271 / 9973 / 0x5A5A5A5A` as a contiguous array. Dart serializes the heap in a **clustered snapshot format**, not a flat memory image, so const data is rebuilt at load time rather than sitting in the file as a plaintext array. Net: the bytecode is opaque to casual scanning but available to Blutter-class deserialization — consistent with the research's assumption (§4.6) that protection rests on *bytecode opacity + handler-learning cost*, not on hiding the interpreter.

---

## 4. Answers to E1's measured questions

| E1 question | Answer |
|---|---|
| (a) Is the dispatch loop present and recognizable as an interpreter? | **Yes** — `while(true)` fetch loop, `code[pc++]` with length-bounds check, binary-search opcode dispatch, generic handlers. Unmistakable VM shape. |
| (b) Did AOT inline / constant-fold the handlers back to the source arithmetic? | **No.** Zero partial evaluation. No source constants in `_interp`; loop not unrolled; bounds checks + stack alloc retained. `vmLicense` holds no arithmetic. |
| (c) Is the bytecode visible as a data array? | **Partly.** Present as a `const List<int>` in the serialized isolate snapshot (Blutter-reconstructable); **not** visible to a flat byte-scan (clustered snapshot format). |
| Did `vm:never-inline` hold? | **Yes.** `_interp` is a distinct, non-inlined ~1988-byte function. |
| Control vs virtualized comparison | **Stark.** Control = algorithm in ~15 readable instructions; virtualized = opaque data array + generic 498-instruction interpreter with no readable algorithm. |

---

## 5. Verdict & implications

**E1 PASSES decisively.** The §10 decision gate ("if AOT flattens it back to the original arithmetic, the whole approach needs rethinking") is **not** triggered. On the exact Refractor SDK (Dart 3.11.3, arm64) and via the same `gen_snapshot` AOT backend Flutter ships, a synthesized switch-loop interpreter survives AOT as a recognizable, non-simplified, data-driven VM. The compiler-optimization risk flagged in research §6.3 did **not** materialize even in the most optimizer-friendly setup (constant bytecode, single call site).

Caveats / notes for the next steps:
- The dispatch compiled to a **binary-search comparison tree** (not a jump table). This is recognizable as a VM, reinforcing research §5.2/§6.2: in Dart the security burden must sit on **ISA diversity + handler hardening (MBA) + small scope**, not on hiding the dispatch.
- The interpreter kept full **bounds-check / smi-untag / boxing** overhead — relevant to **E2** (performance envelope); expect meaningful per-op cost.
- Bytecode opacity is "serialized-snapshot" grade, not encryption — an explicit XOR/const-pool encoding (research §5.3) would still add value against Blutter.

**Recommended next:** E2 (perf envelope) and E6 (equivalence harness) before hardening (E3/E4), per the research's suggested ordering.

---

## 6. Artifacts

Held in the E1 session's notes folder (`E1-artifacts/`), on branch `claude/elated-montalcini-ce8a06` — not in this checkout:

- `vm.dart` — the VM + control source.
- `control-vs-thunk.disasm.txt` — `vmLicense` (thunk) and `plainLicense` (control) ARM64.
- `interp.disasm.txt` — full 498-instruction `_interp` disassembly.

---

## 7. Confirmation on the real Flutter Android artifact (`libapp.so`)

`flutter build apk --release --target-platform android-arm64 --split-debug-info=symbols` produced `app-release.apk` → extracted `lib/arm64-v8a/libapp.so` (ELF arm64, **stripped**, 2.4 MB). Function addresses resolved from the split-debug symbols (`app.android-arm64.symbols`, same BuildID):

| symbol | addr | size |
|---|---|---|
| `vmLicense` | 0x181974 | **0x2c = 44 B** (thunk) |
| `interp` | 0x1819a0 | **0x838 = 2104 B** (interpreter) |
| `plainLicense` | 0x1821d8 | 0x64 = 100 B (control) |

Disassembling the real `libapp.so` by these VMAs reproduces the macOS-AOT result **exactly**:
- `plainLicense` — identical clear arithmetic: `mov #0xbc8f` (48271), `mul`, `mov #0x26f5` (9973), `add`, `mov/movk #0x5a5a5a5a`, `eor`, `and #0xffffff`, `tbnz w2,#0`, `lsl #5`, `sub #7`.
- `interp` — grep of its 2104-byte body for the source constants (`#48271 #9973 0x5a5a 0xbc8f 0x26f5`) returns **none** → handlers are generic and data-driven in the shipped Android artifact too.
- `vmLicense` — 44-byte thunk that calls `interp`.

(Instruction sequences match the macOS AOT byte-for-byte except for relative-branch displacements, which differ only because of link layout.) **Conclusion holds on the real release artifact, not just the dev AOT exe.**
