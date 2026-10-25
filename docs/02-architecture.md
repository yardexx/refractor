# Refractor Virtualization Pass — Architecture

**Status:** design, grounded in the current codebase and the E1–E6 / P1–P4 findings. No code written yet.
**Positioning (from P1–P4):** virtualization is **cost-raising defense-in-depth**, not secrecy. It is applied **surgically** to a few opt-in functions, its security rests on **per-build/per-function diversity + dense ISA + chained decode + MBA**, and it must be composed with the existing passes (rename, string-encrypt) and — for real resistance — a future dynamic/anti-tamper axis. Target: Dart SDK 3.11.3, Flutter AOT arm64.

---

## 1. Where it fits in the existing engine

Refractor already has everything the pass needs; the virtualizer mirrors `string_encrypt` almost exactly.

- **Pass contract** (`lib/src/engine/pass/pass.dart`): `String get name; Future<PassResult> run(Component)`. The "select → plan → transform → validate → report" shape is realized as separate classes orchestrated by `run()` (see `StringEncryptPass`).
- **Registration** (`lib/src/engine/pass/pass_registry.dart`): add a `VirtualizeDefinition()` to `defaultPassRegistry`; config is parsed per-pass from JSON, `enabled`-gated, and ordered by config order.
- **Injection template** (`string_encrypt/runtime/decode_helper_injector.dart`): hand-builds a `Procedure` from kernel nodes, resolves SDK members off `component.libraries` (`dart:core`/`dart:convert`), `library.addProcedure(...)`, and annotates with `@pragma('vm:never-inline')`. The interpreter synthesis is the same operation class, just a bigger body.
- **Body rewriting** (`passes/scoped_kernel_transformer.dart`): `ScopedKernelTransformer extends Transformer` with project-scope filtering + const/annotation-depth tracking — the base for rewriting a target procedure body into a VM call.
- **Selection** (`string_encrypt/selection/...`): a scoped `RecursiveVisitor`. We invert its polarity: string-encrypt is opt-out (whole app minus keeps); virtualize is **opt-in** (only annotated functions).
- **Annotation detection** (`utils/rename_helpers.dart::hasRefractorKeepAnnotation`, consumed in `policy/policy_resolver.dart` — which already notes *"Future … annotations plug in here"*): add `hasRefractorVirtualizeAnnotation(...)` the same way.
- **Vendored kernel toolkit** (`packages/third_party/kernel`): `ast.dart`, `core_types.dart`, `class_hierarchy.dart`, `type_algebra.dart`, `clone.dart`, `verifier.dart` — all available for synthesis, typing, and the E6 verify gate (we already drove `verifyComponent` from here in E6).

### Proposed directory (mirrors `string_encrypt/`)
```
lib/src/engine/passes/virtualize/
  virtualize_pass.dart
  config/           virtualize_config.dart, virtualize_definition.dart
  selection/        virtualize_selector.dart, virtualize_selection.dart   # @virtualize opt-in
  planning/         virtualize_planner.dart, virtualize_plan.dart,
                    isa.dart,            # per-function ISA model + RNG
                    lowering/            # kernel AST -> VM IR
                      lowerer.dart, vm_ir.dart, eligibility.dart
                    assembler.dart,      # VM IR -> encoded bytecode (chained decode)
                    mba.dart             # handler MBA identity selection
  transformation/   virtualize_transformer.dart, virtualize_transform_output.dart
  runtime/          interpreter_injector.dart   # synthesize interpreter+helpers (kernel)
  validation/       virtualize_validator.dart   # E6 gate: differential + verifier
  reporting/        virtualization_record.dart, virtualize_artifact.dart
lib/annotations/    virtualize.dart     # @virtualize marker (ships in the package)
```

---

## 2. Stage-by-stage design

### 2.1 Selection — opt-in `@virtualize`
- New marker annotation `@virtualize` (const class in `lib/annotations/`, detected by `hasRefractorVirtualizeAnnotation`, mirroring keep).
- `VirtualizeSelector` is a scoped `RecursiveVisitor` collecting **procedures** (initially top-level/static methods) that (a) are in project scope, (b) carry `@virtualize`, (c) are **not** kept, and (d) pass the **eligibility** check (§2.2). Ineligible-but-annotated functions are reported as skipped with a reason (never silently miscompiled).
- Output: `VirtualizeSelection { List<Procedure> targets }`.

### 2.2 Lowering + eligibility (the restricted subset)
The single most important scoping decision (research §5.6). **MVP value model = 64-bit `int`/`bool` only** — covers license checks, anti-tamper predicates, key-schedule steps, the stated use cases, with the cleanest MBA story and smallest interpreter.

`eligibility.dart` accepts a function body only if every node maps to a VM op; otherwise the function is **skipped intact** (correctness over coverage). MVP grammar:
- Params/locals of type `int`/`bool`; integer/bool literals.
- Binary ops: `+ - * ^ & | << >> ~` ; comparisons `== != < <= > >=` ; `&&/||` (short-circuit → branches).
- `if/else`, `return`, straight-line blocks, and simple counted loops (phase 2).
- **No**: object/string/double/BigInt values, calls, allocations, closures, async, exceptions, field access. (Each is a future value-model extension; each ballooning the interpreter per §5.6.)

`lowerer.dart` walks the kernel `FunctionNode.body` and emits **VM IR** (`vm_ir.dart`): a small typed instruction list over a stack model — `PushArg i`, `PushConst v`, `Add/Sub/Mul/Xor/And/Or/Shl/Shr/Not`, `CmpEq/Lt/...`, `Dup`, `Jz t`, `Jmp t`, `Ret`. IR targets are label-relative (resolved to word offsets by the assembler). This stage is pure (no kernel mutation yet) and is where E6's reference semantics come from (§2.5).

### 2.3 Planning — per-function ISA + diversity (the security)
`virtualize_planner.dart` produces, **per target function**, a `VirtualizePlan` entry carrying the diversity levers validated in P1–P4:

1. **Per-function, per-build ISA** (`isa.dart`): a build seed (config or random) + function index seeds a PRNG that produces a **dense opcode map** — a 256→op table where *every byte decodes to a valid op* (P3/P4: this removes the "valid-opcode" structural oracle that z3 exploited in P2). Multiple bytes per op; randomized operand order where applicable.
2. **Chained, keyed bytecode encoding** (`assembler.dart`): assemble the IR to a flat `List<int>`, then encode with an **execution-chained stateful keystream** (P3): `enc[i] = plain[i] ^ (state & MASK48); state = state*M + plain[i] + C`. No closed-form keystream to solve (defeats P2's z3 shortcut); forces sequential replay. Straight-line only in MVP (array order == consumption order); branches need a jump-aware chaining scheme (phase 2, §6).
3. **Derived keys, not stored scalars** (P4, with its honest caveat): keys `(state₀, M, C)` are derived at interpreter start by folding over the per-build ISA table, so no obvious key scalar sits in the pool. *Note (P4): this only relocates the key — it is still in the artifact; it raises cost, it does not hide. Genuine blocking needs an env-bound key or anti-tamper (§5).*

> **As implemented (M1 + M3)** (`planning/isa.dart`): item 1 is a per-function **opcode permutation** (each `VmOp` → a distinct byte) rather than the fuller dense 256→op table. Item 2's encoding started as an affine position-keyed XOR in M1 and is now (M3) a **nonlinear** position-keyed keystream (multiply + xorshift), synthesized as a `_ks$N(pos)` helper. Item 3's keys are **derived from a single per-function `seed`** (M3). What remains for M4+: the dense 256→op table, full **execution-STATE chaining** (needs control-flow handling), and environment-derived/anti-tamper keys. This already removes plaintext bytecode from the pool, makes the ISA non-transferring, and defeats the affine two-pair key recovery.
4. **MBA handler selection** (`mba.dart`): pick verified MBA identities for ADD/SUB/XOR (E4/E6) per build; cost is ~+30% (E2) and AOT-durable (E4). Treated as friction, not protection.

`VirtualizePlan { Map<Procedure, PlannedVirtualization> }`, each `PlannedVirtualization` = `{ encodedProgram, isaTable, keyBases, mbaChoices, irForVerification, stackDepth }`.

### 2.4 Transformation — synthesize interpreter + rewrite body
`interpreter_injector.dart` mirrors `DecodeHelperInjector`: resolve `int`/`bool`/`List`/`pragma` SDK members, hand-build the interpreter as a `Procedure` with a `FunctionNode`, `library.addProcedure`, and `@pragma('vm:never-inline')`. Components synthesized:
- `_fold(basis)` — key-derivation over the ISA table.
- `_mAdd/_mSub/_mXor` — MBA handlers (never-inline).
- `_vm(enc, isaTable, args...)` — the dispatch loop: chained `rd()` decode, dense `isaTable[byte]` dispatch, `switch` over ops (switch-loop chosen in E3: ~2× faster than a function table and handler-entangled in one body). Operand stack is `List<int>.filled(n, 0)` sized to the planned depth (E2: right-size to cut the per-call penalty).

**Dispatch style:** switch-loop (E3). **Per-function vs shared interpreter:** MVP ships **one interpreter per function** (so per-function ISA randomization actually diversifies the handler code, not just the data). A shared interpreter + per-function data table is a size optimization for later (E2: interpreter ~2 KB; per-function copies cost code size but maximize diversity — the P-series shows diversity is the main lever, so pay it for the few virtualized functions).

`virtualize_transformer.dart extends ScopedKernelTransformer` then replaces each target's `FunctionNode.body` with `return _vm$f(const [<enc>], const [<isa>], p0, p1, …);` (an unwrapped `bool`/`int`), leaving the signature intact. Records go to the transform output.

### 2.5 Validation — the E6 gate (mandatory, built in)
`virtualize_validator.dart` runs on every build, blocking on failure:
1. **Differential equivalence** — for each virtualized function, run the **IR reference interpreter** (pure Dart, from §2.2) against a **host replay of the synthesized VM semantics** across randomized inputs incl. int64 overflow/edge cases (the E6 harness, 0 mismatches required). Because both the lowered IR and the encoded program are in hand at plan time, this is checkable inside the pass without compiling — the reference interpreter *is* the oracle for "what the original computed."
2. **Kernel well-formedness** — `verifyComponent(NoneTarget, VerificationStage.afterModularTransformations, component, skipPlatform: true)` from the vendored verifier (exactly as demonstrated in E6). Any failure fails the pass.
3. Optional deep gate (off by default, CI): compile the component and run a generated differential harness end-to-end.

### 2.6 Reporting
`VirtualizationRecord` per function: name, op count, bytecode length, interpreter size estimate, ISA seed, MBA set, verify status. `virtualize_artifact.dart` aggregates; `PassReport` metadata: `functions_virtualized`, `avg_slowdown_estimate`, etc. Feeds the existing text/GitHub reporters.

---

## 3. Config & CLI
`config/virtualize_config.dart` (+ `VirtualizeDefinition`): JSON keys
```jsonc
"virtualize": {
  "enabled": true,
  "seed": 0,                 // 0 => random per build (diversity); fixed for reproducible builds
  "perFunctionIsa": true,
  "encodeBytecode": true,
  "deriveKeys": true,
  "mbaHandlers": true,
  "maxOps": 4096,            // skip functions whose IR exceeds this (cost guard, E2)
  "deepVerify": false        // run compile-and-run E6 gate
}
```
Ordering: run **after** rename + string-encrypt (so the interpreter's own names/strings are already obfuscated), per research §6.1. The pass is enabled only when the user both configures it and annotates functions.

---

## 4. Phasing (de-risked increments)
- **M0 — skeleton (done):** pass wired into registry/config, `@virtualize` selection, eligibility, lowering for int/bool expressions incl. ternary branches, switch-loop interpreter, exact stack sizing, defensive opcode trap, atomic rollback, E6 gate on. Verified end-to-end on the E1/E5 predicate.
- **M1 — diversity (done):** per-function, seed-derived `IsaProfile` = opcode **permutation** + **position-keyed XOR encoding** of every word (opcodes and operands). The assembler emits permuted+encoded words; the synthesized interpreter decodes per fetch (`code[pc] ^ ((keyA*(pc+1)+keyB) & mask)`) and dispatches on the per-function numbering; the reference oracle uses the same profile. Driven by the pass `seed` config (0 ⇒ random per build; fixed ⇒ reproducible). Result: dispatch numbering doesn't transfer across functions/builds, and the bytecode is no longer plaintext in the object pool (E5's finding) — unit-tested at the assembler level (encoded words contain none of the source constants). *Not yet M1:* chained/stateful decode (P3) and derived/environment keys (P4) — keys are per-function constants baked into the interpreter for now; operand-order randomization deferred.
- **M2 — handler hardening (done):** the synthesized arithmetic/bitwise handlers (`add/sub/xor/and/or` and their `*Imm` superop forms) are emitted as **MBA identities** (E4-durable; equal in value to the plain op, so the reference oracle stays plain and E6 holds). **Superoperators** fuse `pushConst C; <binop>` into one `<binop>Imm` handler (a peephole over the IR), shrinking the bytecode and giving those handlers a compound, non-primitive shape. *Partial entanglement:* superops + MBA inflate and compound each handler; full inter-handler state-threading (Blazytko) is deferred because a correct version must be branch-safe (M4 control flow first). Comparison handlers are left plain for now.
- **M3 — encoding hardening (done):** M1's **affine** keystream (two word-pairs solve `keyA`/`keyB`) is replaced by a **nonlinear position-keyed** keystream — `h=(pos+1)^seed; h*=seed|1; h^=h>>>29; h*=(seed^golden)|1; h^=h>>>32; h&mask` — synthesized as a per-function `_ks$N(pos)` helper that the interpreter calls per fetch. **Derived keys:** only the single per-function `seed` ships; the two multipliers are derived from it (P4 caveat holds — relocates, doesn't hide). **Operand-order randomization:** commutative ops (`+ * ^ & | == !=`) have their operands swapped per a per-function seed, except when an operand is a constant literal (so `pushConst C; <binop>` stays fusable into a superop). All branch-safe (pure function of `pos`). *Full execution-STATE chaining* (P3) remains deferred to after M4, since it is incompatible with `jz`/`jmp` until control-flow handling exists (same `pos` reached via different paths ⇒ different state ⇒ wrong decode).
- **M4 — control flow:** statement-level `if/else`, locals, counted loops → jump-aware decode, which in turn unlocks execution-state-chained encoding.
- **M5 — scale/perf:** optional shared-interpreter mode, right-sized stacks, cost curve enforcement (E2) via `maxOps`.
- **Parallel track — dynamic axis (§5):** the only path to real blocking; scoped as separate work.

> **Roadmap note:** M2/M3 were reordered to a **security-first** split (handler hardening, then encoding hardening) by decision after M1, moving control-flow expansion to M4. The hardening content is unchanged from the original single M3 bundle; it is now staged for piece-by-piece review.

---

## 5. Honest limits baked into the design (from P4)
A deterministic predicate's key material necessarily ships in the artifact; Blutter + disassembly + an SMT/emulation-capable LLM agent recovered **every** realistically-provisioned build in the P-series. Therefore the architecture must **advertise cost-raising, not secrecy**, and:
- Keep **per-build diversity aggressive** — it is the one lever that removes amortization (each build re-pays the full reversing cost).
- Treat **encoding/derived-keys as cost multipliers** (they defeat the cheap z3 shortcut and force hand-built emulation — measured hard, ~14 min/133k tokens for an LLM), not as hiding.
- For functions that can be **environment-bound** (device/runtime-derived inputs), derive the decode key from that environment so it is genuinely absent from the static artifact — the only static-analysis "block" we found. Not applicable to pure serial predicates.
- Plan a **dynamic/anti-tamper layer** (code-checksum keys via FFI self-read, anti-debug/anti-Frida — note Blutter auto-emits a Frida script) as the real resistance axis; virtualization raises the static cost that makes dynamic attack necessary.

---

## 6. Key risks
- **Correctness of synthesized kernel** (typing, Smi/Mint tagging, 64-bit wrap): mitigated by the E6 gate (differential + verifier) as a hard precondition to emit.
- **Branch/jump chained-decode** (M2): array order ≠ execution order breaks the straight-line chain; needs a decode-order or trace-independent scheme. Design before M2.
- **AOT folding** (E1 said no, but hardened constructs differ): re-check via `gen_snapshot --snapshot_kind=app-aot-assembly` that MBA/chained decode survive (E4 method) as a CI assertion.
- **Code-size blow-up** with per-function interpreters: bounded by surgical scope + `maxOps`; revisit shared-interpreter mode if the annotated set grows.
- **Determinism for reproducible builds:** `seed: 0` (random) maximizes diversity but breaks reproducibility; document the trade and allow a pinned seed.

---

## 7. Test strategy
- Unit: lowering (kernel→IR) and assembler (IR→encoded, round-trip decode) with property tests.
- Golden: ISA generation determinism per seed; two seeds ⇒ disjoint maps.
- Correctness: the E6 differential harness as a reusable gate (already built) + `verifyComponent`.
- Security regression: the blind-attacker bundle generator (P2–P4) wired as a CI job asserting the object pool exposes no plaintext predicate and that the cheap z3 shortcut fails.
- Perf: the E2 benchmark as a cost-curve guard.

---

## 8. Reused vs new
**Reused as-is:** Pass/registry/config framework, `ScopedKernelTransformer`, SDK-member resolution pattern, `addProcedure`+`vm:never-inline` injection, vendored `verifier.dart`, reporters, project scope + policy + annotation detection.
**New work:** eligibility + kernel→VM-IR lowering, per-function ISA generator, chained-decode assembler, MBA selector, interpreter synthesizer (bigger than the decode helper), the E6-based validator, and the `@virtualize` annotation.
The novelty is concentrated in **lowering + ISA/assembler + interpreter synthesis**; everything else is the string-encrypt recipe at larger scale — exactly as the research predicted (§3.3).
