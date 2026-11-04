# Code Virtualization for Dart/Flutter: A Research Foundation

**Status:** Research phase — no architecture, classes, or implementation plan proposed here.
**Target system:** Refractor, a Dart kernel-IR (`.dill`) rewriting obfuscator (Dart SDK 3.11.3).
**Date:** 2026-10-17
**Author:** Research spike for the Refractor project.

**Epistemic key used throughout.** *[Fact]* marks a claim traceable to a primary source or the Refractor source tree. *[Inference]* marks a conclusion I draw from facts but that no single source states. *[Hypothesis]* marks a plausible but untested proposition that should be validated before anything is built on it. Where I could not reach or fully verify a source, I say so explicitly.

---

## 1. Executive Summary

Code virtualization is the strongest-reputation technique in the software-protection toolbox and, not coincidentally, the most expensive one to build and to run. Instead of hiding what a function does through local rewrites — renaming, string encryption, control-flow flattening — virtualization *replaces the function entirely* with a block of custom bytecode plus an interpreter that executes it. The original instructions never exist in recoverable form in the shipped artifact; what ships is data (the bytecode) and a dispatch loop. An attacker who wants the logic back must first reverse-engineer the interpreter, recover the instruction-set semantics, and only then "devirtualize" the bytecode into something resembling the original. That extra indirection is precisely why virtualization raises the cost of both human and, increasingly, LLM-assisted reverse engineering.

The core finding of this research is that virtualization is **achievable in principle for Refractor**, because Refractor already operates at exactly the right altitude (the Dart kernel AST) and already contains the two hardest pieces of machinery a virtualizer needs: a code-synthesis-and-injection facility (`KernelHelperInjector` + `SdkIndex`) and a body-rewriting transformer framework (`ScopedKernelTransformer`). *[Fact, from the Refractor source tree.]* The string-encryption pass is a working, shippable existence proof: it already synthesizes a runtime helper out of raw kernel nodes and redirects call sites into it.

The central tension is **scope versus value**. A *full* Dart virtualizer — one that can express arbitrary Dart including generics, closures, `async`/`await`, exceptions, and the full object/dispatch model — is a research-grade undertaking whose interpreter would be enormous, slow, and itself a large attack surface. A *restricted* virtualizer targeting integer/boolean arithmetic, comparisons, simple branching, and constant/string handling is tractable, maps cleanly onto the literature (Tigress, VMProtect, and academic VM-obfuscation all began and largely remain here), and is where virtualization delivers most of its anti-RE value in practice. *[Inference.]*

Three constraints are non-negotiable and set honest expectations:

1. **No provable secrecy.** Barak et al. proved that general-purpose "virtual black-box" obfuscation is impossible; virtualization buys *cost and time*, not cryptographic hiding. *[Fact.]*
2. **Generic devirtualization attacks exist and work.** Rolles (2009), Syntia (2017), VMHunt (2018) and successors recover VM handler semantics automatically, with Syntia reporting >94% success on VMProtect/Themida arithmetic handlers. Diversity and handler obfuscation raise the cost of these attacks but do not defeat them. *[Fact.]*
3. **Performance cost is severe.** Published measurements of Tigress-style virtualization show slowdowns from ~5× up to 120–337× on hot code depending on configuration, plus substantial size growth. Virtualization must be applied surgically to small, security-critical fragments, never broadly. *[Fact.]*

The recommendation of this phase is to treat virtualization as a *future pass* targeting a deliberately restricted expression/statement subset, prototyped behind validation experiments (Section 10) before any architecture is committed. Refractor's existing `rename` + `string_encrypt` + (returning) control-flow passes remain the right default; virtualization is a high-cost add-on for a small set of annotated hot spots.

---

## 2. Problem Definition

### 2.1 The fundamental technical problem

Refractor's job is to raise the cost of understanding a shipped Dart/Flutter program to an adversary who possesses the final artifact and unlimited offline time. For Flutter release builds that artifact is an AOT snapshot (`libapp.so` on Android, embedded in the Mach-O on iOS) containing native ARM64/x64 machine code plus Dart object metadata. *[Fact; see Flutter reversing sources in §4.6.]*

The specific problem this research addresses: **can a selected Dart function's logic be transformed so that, after AOT compilation, the function's original algorithm cannot be read directly out of the native code, and can only be recovered by first reverse-engineering an interpreter and its bytecode?**

Formally, virtualization replaces a function `f` with a pair `(B_f, I)` where `B_f` is a bytecode encoding of `f` for a (preferably per-function, per-build randomized) instruction set, and `I` is an interpreter such that `I(B_f, args) ≡ f(args)` for all inputs (semantic equivalence). The security goal is that recovering `f` from `(B_f, I)` is substantially more expensive than recovering `f` from a conventionally compiled `f`. *[Inference, standard framing synthesized from Tigress/VMProtect docs.]*

### 2.2 Threat model

- **Adversary capability:** Full static access to the artifact; standard tooling (IDA/Ghidra/Binary Ninja, and Dart-specific tools **Blutter** and **reFlutter**); dynamic instrumentation (Frida); and increasingly **LLM agents** that drive those tools. *[Fact; §4.6, §4.7.]*
- **Adversary goal:** Recover the algorithm of a specific function (e.g., a license check, anti-tamper routine, key-derivation step, root/jailbreak detection), or lift it faithfully enough to patch or reimplement it.
- **Defender goal:** Maximize the *analyst-hours* and *tool-development cost* per recovered function, within a strict runtime/size budget, for a *small* set of designated functions — not the whole app.

This is explicitly a **cost-raising** model, consistent with MATE (man-at-the-end) software protection generally, not a secrecy-guarantee model. *[Inference, grounded in §8.]*

### 2.3 Why this is hard in the Dart/Flutter setting specifically

Three properties make the Dart case different from the classic C/x86 virtualizers:

1. **Refractor virtualizes at the IR level, and the VM is itself AOT-compiled.** Unlike VMProtect/Themida, which inject a hand-written native interpreter into an already-compiled binary, a Refractor virtualizer would synthesize the interpreter *as Dart kernel*, which the Dart AOT compiler then turns into native code along with everything else. This makes Refractor structurally closer to **Tigress** (a source-to-source C virtualizer) than to binary protectors. *[Inference from Refractor's pipeline + Tigress's design.]*
2. **The handlers are high-level and typed.** The interpreter's handlers manipulate Dart values (tagged objects, `int`/`double`/`String`, lists) through the Dart object model, not raw registers. This raises both the semantic floor (you cannot cheaply virtualize a pointer dereference) and, helpfully, the abstraction the attacker must bridge.
3. **Dart's own bytecode interpreter is gone.** The Dart VM removed its bytecode (DBC) execution mode in late 2020. *[Fact: Dart SDK commit "Remove bytecode mode from the VM", Oct 2020.]* There is therefore **no reusable in-runtime interpreter to piggyback on**; any virtual machine must be synthesized by Refractor and compiled as ordinary Dart. *[Inference.]*

---

## 3. Technical Background

### 3.1 Where virtualization sits among obfuscation transformations

Collberg et al.'s classic taxonomy divides obfuscating transforms into *layout*, *data*, and *control* transformations, and introduces the quality axes still used today: **potency** (how much harder to understand for a human), **resilience** (how hard to undo automatically), **stealth** (how hard to detect that a transform was applied), and **cost** (runtime/size penalty). *[Fact; Collberg et al., "A Taxonomy of Obfuscating Transformations", 1997, and "Manufacturing cheap, resilient, and stealthy opaque constructs", POPL'98.]* Virtualization is the most potent and resilient *control* transformation, and also the most costly.

The immediate neighbours Refractor should understand as *components* of, or *alternatives* to, virtualization:

- **Control-flow flattening**: replace structured control flow with a dispatcher + state variable. A VM dispatch loop is essentially flattening taken to its logical extreme, where the "state" is a virtual program counter and the basic blocks are handlers. *[Inference.]*
- **Opaque predicates**: conditions whose value is known to the obfuscator but hard for an analyst to resolve; used to inject bogus branches and to harden VM internals (Tigress exposes `identity`, `modular`, `mba`, `environment` invariant kinds). *[Fact; Tigress `--VirtualizeOpaqueInvariantKinds`.]*
- **Mixed Boolean-Arithmetic (MBA)**: rewrite expressions as tangled mixtures of arithmetic and bitwise ops that resist SMT-based simplification. MBA is both a standalone data-obfuscation and the preferred way to build resilient opaque predicates and to obfuscate VM handlers. *[Fact; §5.4.]*

### 3.2 The computer-science concepts underneath virtualization

- **Interpretation and the interpreter/compiler duality.** A virtualizer is a *specializing compiler* that emits, for each function, a bytecode program plus a (shared or per-function) interpreter. The theoretical frame is the **Futamura projections**: specializing an interpreter with respect to a program yields a compiled program; running an interpreter over bytecode is the inverse direction. Virtualization deliberately chooses the slow, hard-to-invert direction. *[Fact, standard PL theory; Inference on the "deliberately slow" framing.]*
- **Interpreter dispatch.** The dispatch mechanism — how the loop selects the handler for the next opcode — is the defining structural signature of a VM and the first thing an attacker fingerprints. The main options (Section 5.2) trade performance against stealth.
- **Instruction-set design and randomization.** The potency of virtualization against *generic* attacks comes largely from **diversity**: randomizing opcode encodings, operand order, operand model (stack vs register), and the handler set so that one reverse-engineered VM does not transfer to the next build. *[Fact; Tigress, Oreans, and CoDiver-style ISR work.]*
- **Semantic equivalence and verification.** The transform must preserve observable behaviour. In the kernel-IR setting this additionally means the result must pass the kernel **verifier** and be well-typed enough for the AOT compiler. *[Fact; Refractor vendors `verifier.dart` and `type_algebra.dart`.]*

### 3.3 Refractor's current capabilities relevant to virtualization

From the Refractor source tree *[Fact]*:

- It compiles a Dart entrypoint to kernel (`dart compile kernel`), loads the `.dill` into an in-memory `Component`, runs ordered passes that mutate the AST, re-serializes with `BinaryPrinter`, and recompiles to the target. (`lib/src/engine/engine.dart`.)
- Each pass follows a fixed 5-stage shape: **select → plan → transform → validate → report** (`lib/src/engine/pass/`), with mutation confined to the transform stage via `ScopedKernelTransformer`.
- The **string-encryption pass** already demonstrates the full virtualization-adjacent recipe: `SdkIndex` resolves `dart:core`/`dart:convert` members; a runtime decoder `FunctionNode` is built *entirely from hand-constructed kernel nodes*; `KernelHelperInjector.addStaticProcedure` injects it as a top-level static with `@pragma('vm:never-inline')`; and the transformer rewrites targeted literals into `StaticInvocation`s of the helper. (`lib/src/engine/passes/string_encrypt/`.)
- The vendored kernel library includes `core_types.dart`, `class_hierarchy.dart`, `type_algebra.dart`, `clone.dart`, and `verifier.dart` — the full toolkit needed to synthesize well-typed code. (`packages/third_party/kernel/`.)

**The significance** *[Inference]*: injecting an interpreter and redirecting a method body into it is *the same operation class* Refractor already performs for string decoding — synthesize a static helper, replace a node with a call to it. The novelty is not the mechanism but (a) the complexity of the synthesized helper (a dispatch loop vs a decode function) and (b) the planning stage that must *compile a method body down to bytecode*.

---

## 4. Existing Solutions

### 4.1 Commercial binary virtualizers — VMProtect

VMProtect translates selected x86/x64 (and, in recent versions, ARM64) code into bytecode for an embedded interpreter with its own command set; the protected fragment never returns to native form while running. It layers mutation (junk instructions, dead code, random conditional jumps) on top, and can instantiate *multiple distinct VMs* across different fragments so one reverse-engineered VM does not cover the whole binary. *[Fact; VMProtect user manual, https://vmpsoft.com/vmprotect/user-manual, and overview https://vmpsoft.com/vmprotect/overview. Vendor-authored; treat security claims as self-reported.]*

### 4.2 Commercial binary virtualizers — Oreans (Code Virtualizer, Themida)

Oreans converts x86/x64/ARM64 instructions into virtual opcodes for an embedded VM, claiming per-application uniqueness of opcodes and VM so generic attacks do not transfer. Themida adds **nested virtualization** and keeps its VM context and virtual stack *inside the binary image* rather than on the native stack (a structural difference from VMProtect). A 2009 USENIX WOOT analysis notes Themida offers multiple VM *templates* (RISC-64, RISC-128, CISC, CISC-2), with instances from the same template differing in opcode encodings. *[Fact; Oreans https://oreans.com/CodeVirtualizer.php, https://www.oreans.com/Themida.php (vendor); Rolles, WOOT'09, https://static.usenix.org/events/woot09/tech/full_papers/rolles.pdf (independent); back.engineering devirtualization write-ups, https://back.engineering/tags/obfuscation/ (practitioner, independent).]*

A sobering operational data point: a 2026 ANY.RUN study of malware "protected" by VMProtect/Themida found most samples used only compression/encryption and **few used true code virtualization**, i.e. the protection was often weaker in practice than its reputation. *[Fact; https://any.run/cybersecurity-blog/vmprotect-themida-malware-analysis/. Relevance to Refractor is contextual, not technical.]*

### 4.3 Academic/source-level virtualizer — Tigress

Tigress (Christian Collberg's group, Arizona) is the most important reference for Refractor because it virtualizes at the **source level** (C), which is the closest analogue to Refractor's IR-level approach. Its `virtualize` transform turns a function into a function-specific interpreter, choosing a random ISA and a random dispatch method from a seed, enabling large-scale diversification from one source. *[Fact; https://tigress.wtf/ and https://tigress.wtf/virtualize.html.]*

Tigress's option surface is effectively a *catalogue of virtualization design choices* and is reproduced in condensed form in Section 5. Highlights *[Fact, from the virtualize docs]*: operand models (`stack`/`register`/`mixed`); duplicate instructions with different signatures; randomized opcodes and operand order; **superoperators** (merging primitive instructions into compound opcodes); dispatch methods (`switch`, `direct`/`indirect` threading, `call` threading, `ifnest`, table-search, `concurrent`); bytecode XOR encoding; opaque-invariant hardening of handlers, the VPC, and decode routines; **bogus functions/loops** interleaved with the real one; implicit information flow; self-modifying ("dynamic") bytecode; and reentrant interpreters.

### 4.4 The next-generation critique (Blazytko & Schloegel)

A Recon 2022 / HITB Amsterdam 2023 talk argues that common VM protectors mostly rely on **fixed instruction-set architectures and weakly obfuscated individual components**, which is exactly what makes them vulnerable to compiler-optimization-, symbolic-execution-, and program-synthesis-based attacks. Their proposed direction: **target-specific (per-function) ISAs and intertwined VM components** so handlers cannot be isolated and learned independently. *[Fact; https://conference.hitb.org/hitbsecconf2023ams/session/the-next-generation-of-virtualization-based-obfuscators/.]* This is the single most important design lesson for a *new* virtualizer: diversity and component-entanglement, not a clever opcode set, are what resist modern attacks.

### 4.5 Devirtualization / attack tooling (what we are defending against)

- **Rolles (WOOT'09)** — foundational manual+static methodology for lifting VM handlers to IR and reconstructing the original program. *[Fact.]*
- **Syntia (USENIX Security 2017)** — program synthesis guided by Monte Carlo Tree Search over execution-trace windows; synthesized arithmetic handler semantics for VMProtect and Themida with **>94% success**, and learned 489/500 MBA-obfuscated expressions. *[Fact; https://www.usenix.org/conference/usenixsecurity17/technical-sessions/presentation/blazytko.]*
- **VMHunt (CCS'18)** — identifies and extracts virtualized snippets from traces and simplifies them. *[Fact; https://faculty.ist.psu.edu/wu/papers/vmhunt-ccs18.pdf.]*
- **Xyntia / Pushan (2026)** — successors; Pushan is described as a *trace-free* devirtualization method avoiding symbolic-execution scalability limits. *[Fact that they exist; preprint, not independently verified by me: https://www.alphaxiv.org/abs/2603.18355v1.]*
- **Naiqian Zhang dissertation (UNH, 2025)** — a taxonomy of VM diversification techniques plus automated identification of them in real obfuscators; the closest thing to a systematic academic treatment. *[Fact; https://scholars.unh.edu/dissertation/2946. I have the abstract/summary, not the full text.]*

The through-line: the standard attack decomposes the VM into independent handlers, learns each handler's semantics by synthesis/symbolic execution, then re-expresses the bytecode in those recovered semantics. Defenses work by **breaking that decomposition** (entangled components, implicit flow, per-function ISA) and by **inflating each handler's apparent complexity** (MBA, opaque predicates, superoperators).

### 4.6 Dart/Flutter-specific reverse-engineering tooling

- **Blutter** (Worawit Wangwarunyoo) reads the Dart AOT snapshot using the Dart runtime's own source, extracts metadata, and emits symbols, pseudo-code, assembly, and ready-made Frida scripts — without launching the app. *[Fact; HITB 2023 slides, https://conference.hitb.org/hitbsecconf2023hkt/materials/ (B(l)utter talk).]*
- **reFlutter** patches and recompiles the Flutter engine to aid instrumentation/interception. *[Fact; same talk; Guardsquare overview https://guardsquare.com/blog/current-state-and-future-of-reversing-flutter-apps.]*
- **OWASP MASTG** documents Flutter reversing as a standard technique. *[Fact; https://mas.owasp.org/MASTG/techniques/android/MASTG-TECH-0112.]*
- A recurring theme across these sources: the **Dart snapshot format changes between releases**, breaking parsers each version — which simultaneously *helps* defenders (tooling lags) and explains Refractor's hard SDK pin (3.11.3). *[Fact + Inference.]*

**Implication for Refractor** *[Inference]*: a virtualizer must assume Blutter-class tools can recover the *interpreter's* Dart-level structure (class names already handled by `rename`, pseudo-code of handlers). The protection value therefore rests on the **bytecode being opaque data** and the **handler semantics being expensive to learn**, not on the interpreter being hidden.

### 4.7 LLM-assisted reverse engineering (the stated motivation)

The user's motivation is resistance to LLM-driven RE. The current evidence:

- LLMs are **useful assistants but unreliable autonomous deobfuscators**. A 2025 study of seven commercial models across bogus-control-flow, instruction-substitution, control-flow-flattening, and their combination found "striking performance variations" and **universal failure against *combined* obfuscation**. *[Fact; https://arxiv.org/html/2504.10557v1.]*
- LLM-based decompilation (e.g., LLM4Decompile) works best **paired with traditional decompilers** (Ghidra), and struggles with long functions (token limits), semantic drift, and hallucination. *[Fact; https://arxiv.org/html/2505.19887v1 and related.]*
- At least one line of argument notes that many protections **implicitly assume human cognitive limits** and may not hold against tireless LLM agents — cutting both ways. *[Fact that the argument is made; https://arxiv.org/html/2504.10557v1.]*
- An Elastic-style benchmark of LLM RE vs iterative obfuscation reported that **hardened Tigress options raised analysis cost/time up to ~4×** without necessarily flipping success/failure. *[Fact that this was reported; source reached only via a mirror, https://www.hendryadrian.com/?p=99697 — treat the specific numbers with caution.]*

**Synthesis** *[Inference]*: virtualization is *especially* well-suited to raising LLM cost, because (a) it converts readable control flow into an interpreter + opaque data array, defeating the pattern-matching LLMs are strongest at; (b) it makes the relevant context long and uniform (a dispatch loop + a byte array), which stresses token limits and induces hallucination; and (c) *combined* transforms (virtualization + MBA handlers + renaming + string encryption, all of which Refractor can stack) are where even strong models were observed to fail. This is a *hypothesis about effectiveness*, consistent with the evidence but not directly measured for Dart.

---

## 5. Relevant Algorithms and Techniques

### 5.1 The virtualization pipeline (abstract)

1. **Select** target functions/fragments (annotation-driven, e.g. extend `@Refractor.keep` semantics to an opt-in `@virtualize`).
2. **Lower** the fragment's kernel AST to a simple intermediate form (expression trees / three-address-like ops) over a chosen value model.
3. **Design an ISA** for the fragment (opcode set, operand model, encodings) — ideally randomized per function/build.
4. **Assemble** the lowered form into a bytecode array `B_f` (data).
5. **Synthesize** the interpreter `I` as kernel nodes (dispatch loop + handlers) via `SdkIndex`/`KernelHelperInjector`.
6. **Rewrite** the original body to `return I(B_f, capturedEnv, args)`.
7. **Harden** handlers/VPC/decode (MBA, opaque predicates, bogus ops).
8. **Verify** semantic preservation + kernel well-formedness.

Steps 5–6 reuse Refractor's existing machinery almost directly; steps 2–4 and 7 are the genuinely new work. *[Inference.]*

### 5.2 Dispatch mechanisms (the key structural choice)

| Dispatch | Mechanism | Perf (relative) | Stealth / resistance | Feasible in AOT Dart? |
|---|---|---|---|---|
| **Switch** | `while(true){ switch(op){...} }` | Baseline; two indirect jumps/op; high branch-misprediction (reported 81–98% in C switch interpreters) | Most recognizable VM shape | **Yes**, trivially |
| **Direct/indirect threading** | jump to next handler via labels-as-values / jump table | Faster (removes return jump) | Harder to fingerprint | **No direct threading** — needs computed `goto`/labels-as-values (GNU C extension), which Dart lacks. *Indirect via a handler-function table is possible* |
| **Call threading** | each op is a function call | Slower; larger bytecode | Different shape | **Yes**, via function-pointer table |
| **If-nest / table search** | nested `if` / binary-search over opcodes | Slower | Obscures dispatch table | **Yes** |

*[Facts on C dispatch costs: TCD-CS-2006-51, https://publications.scss.tcd.ie/tech-reports/reports.06/TCD-CS-2006-51.pdf, citing Ertl & Gregg; Tigress dispatch catalogue. The "Feasible in AOT Dart?" column is Inference: Dart has no computed-goto/labels-as-values, so classic direct threading is unavailable; a table of handler closures/top-level functions is the Dart-idiomatic substitute.]*

**Key constraint** *[Inference]*: the most performant classic techniques (direct threading via computed goto) are **not expressible in Dart**. A Dart VM is realistically a `switch` loop or a function/closure dispatch table. This both caps performance and makes the VM *easier to fingerprint* — which pushes the security burden onto handler obfuscation and ISA diversity.

### 5.3 Instruction-set diversity (the main resilience lever)

From Tigress's option set, the diversity knobs that matter *[Fact]*: randomized opcode numbering (`--VirtualizeRandomOps`), randomized operand order (`--VirtualizeRandomizeOperandOrder`), duplicate instructions with differing signatures (`--VirtualizeMaxDuplicateOps`), operand model choice (`stack`/`register`/`mixed`), and **superoperators** (`--VirtualizeSuperOpsRatio`, `--VirtualizeMaxMergeLength`) that fuse common instruction sequences into single opaque opcodes. CoDiver-style **instruction-set randomization** additionally remaps the bytecode→handler relationship per program — but its authors note that randomizing opcodes alone leaves the **bytecode frequency distribution** intact, which statistical attacks exploit; superoperators and padding help flatten it. *[Fact that the CoDiver limitation was reported; I do not have a direct URL for the CoDiver paper and could not verify it beyond the search summary.]*

### 5.4 Handler hardening — MBA and opaque predicates

- **MBA** rewrites each handler's arithmetic into tangled Boolean+arithmetic identities that resist SMT simplification. MBA-Blast (USENIX Security 2021) reports MBA "can effectively hide the secret data/algorithm from both static and dynamic reverse engineering, including SMT-based analyses," while also noting prior deobfuscators suffer heavy performance penalties or produce false simplifications. *[Fact; https://par.nsf.gov//servlets/purl/10318190.]*
- **But linear MBA is increasingly solvable.** GAMBA and related work report that *linear* MBAs can be solved systematically, and that compiler optimization measurably shrinks MBA complexity — so MBA must be *non-linear* and re-applied after any optimization to retain value. *[Fact; GAMBA/ERCIM, https://ercim-news.ercim.eu/en139/special/generating-mixed-boolean-arithmetic-expressions-through-equality-saturation.]*
- **Opaque predicates** (ideally MBA-backed, with `global`/`interprocedural` resilience in Tigress's terms) inject bogus branches into handlers and the dispatcher, and tie decode routines to runtime-derived invariants (Tigress `environment` kind) so handlers cannot be analyzed in isolation. *[Fact; Tigress options.]*

**Dart caveat** *[Inference]*: MBA operates on fixed-width integer semantics. Dart `int` is 64-bit with well-defined wraparound in AOT, so standard 64-bit MBA identities apply — but any virtualizer mixing `int`/`double`/`BigInt` must track types, because MBA identities do not hold across them.

### 5.5 Anti-dynamic-analysis techniques

Bogus functions interleaved with the real one (`--VirtualizeNumberOfBogusFuns`), bogus per-dispatch loop computations, implicit information flow between VPC and dispatcher (`--VirtualizeImplicitFlowPC`), and **self-modifying/dynamic bytecode** (XOR/XTEA re-encoded blocks) all target trace-based and symbolic attackers. *[Fact; Tigress options.]* Most are expensive; dynamic/self-modifying bytecode in particular is likely **impractical in AOT Dart** because Dart has no mechanism to execute freshly generated code at runtime (no eval, no JIT in release mode). *[Inference — this is a hard constraint, see §8.]*

### 5.6 Value model and the Dart object system

The single biggest *scoping* decision. Options, from cheapest to most ambitious *[Inference]*:

- **Integer/boolean-only stack machine** (operands are `int`/`bool`): covers arithmetic, bitwise, comparisons, simple branches. Smallest interpreter, cleanest MBA story. Covers the bulk of license-check / anti-tamper / key-schedule logic.
- **+ Strings/constants**: add a constant pool and string ops (reuses the existing string-encrypt codec).
- **+ Tagged dynamic values** (`Object?` stack): allows calling into Dart objects/methods via reflection-free `InstanceInvocation` thunks — but now the interpreter must encode dispatch, which balloons it and leaks structure.
- **Full Dart** (closures, generics, async, exceptions): research-grade; the interpreter must re-implement large parts of Dart semantics. Not recommended as a target.

---

## 6. Comparative Analysis

### 6.1 Virtualization vs Refractor's other (current/returning) passes

| Dimension | Rename (live) | String encrypt (live) | Control-flow flatten (planned return) | **Virtualization** |
|---|---|---|---|---|
| Potency | Low–med | Low (data only) | Medium | **High** |
| Resilience to automated attack | Low (re-derivable) | Low–med | Medium (flattening is well-studied) | **High** (but devirtualization exists) |
| Runtime cost | ~0 | Low (per-string decode) | Low–med | **High (5×–300×+ on hot code)** |
| Size cost | ~0 | Low | Low | **High** (bytecode + interpreter) |
| Build/maintenance complexity | Medium | Medium | Medium–high | **Very high** |
| Coverage | Whole app | Whole app | Whole app | **Small, surgical set only** |

*[Perf/size facts from §7; the rest Inference calibrated to the literature.]*

**Conclusion** *[Inference]*: virtualization is not a replacement for the existing passes but a *capstone* applied to a handful of annotated functions, ideally *after* rename/string-encrypt and *composed with* MBA/opaque-predicate hardening.

### 6.2 Dispatch strategy trade-off for Dart

Given §5.2, the realistic Dart choices are **switch-loop** (simplest, slowest, most recognizable) vs **function/closure dispatch table** (call-threading-like: different shape, still recognizable, extra call overhead). *[Inference.]* Neither achieves C-interpreter performance. The practical lever is therefore **ISA diversity + handler hardening + small scope**, not dispatch cleverness.

### 6.3 Source/IR-level (Tigress-like) vs binary-level (VMProtect-like) for Refractor

Refractor is structurally committed to IR-level (Tigress-like) because it operates on kernel before AOT. *[Fact.]* Trade-offs *[Inference]*:

- **Advantage:** Works with Dart semantics, types, and the kernel verifier; portable across Android/iOS/targets since AOT does the lowering; reuses existing injection machinery.
- **Disadvantage:** The interpreter is compiled by Dart's AOT compiler, which will *optimize and inline* it — potentially simplifying handlers (helpful to the attacker). `@pragma('vm:never-inline')` and opaque invariants are the counter-measures, already used by the string pass. *[Fact that the pragma is used; Inference on optimization risk — needs experimental confirmation, see §10.]*

---

## 7. Feasibility Assessment

### 7.1 Currently achievable (high confidence)

- **Injecting a synthesized interpreter** as a top-level static and redirecting a method body to it. *[Fact — mechanically identical to the string-encrypt helper injection.]*
- **A restricted stack-machine VM over `int`/`bool`** with `switch` dispatch, a randomized opcode table, and a XOR-encoded bytecode array (reusing the existing codec). *[Inference, high confidence — every primitive needed already exists in the vendored kernel + `SdkIndex`.]*
- **Composition with existing passes** (run virtualization, then rename/string-encrypt the generated interpreter too). *[Inference.]*
- **Per-build ISA randomization** driven by the existing `seed` config. *[Inference.]*

### 7.2 Requires experimentation (medium confidence)

- **Resisting AOT optimization/inlining** of handlers (does `vm:never-inline` + opaque invariants actually preserve the intended complexity in the final snapshot?). Needs a Blutter-based inspection experiment (§10).
- **Acceptable performance envelope** for real hot paths. Needs benchmarking; the literature's 5×–300× range is wide and configuration-dependent.
- **Non-linear MBA handler hardening** that survives AOT's optimizer and genuinely raises SMT/synthesis cost on Dart `int`. 
- **Function/closure dispatch** as a stealthier alternative to `switch`, and whether AOT devirtualizes the indirect calls.
- **Superoperators / operand-order randomization** to flatten bytecode frequency statistics.

### 7.3 Likely impractical (for this platform)

- **Self-modifying / dynamic bytecode** — Dart release/AOT has no runtime code generation or `eval`; XOR-at-entry decoding of a *data* array is fine, but true self-modifying *code* is not. *[Inference, high confidence.]*
- **Direct-threaded dispatch via computed goto** — no labels-as-values in Dart. *[Fact about Dart; Inference about consequence.]*
- **Virtualizing `async`/`await`, generics, and closures faithfully** at reasonable cost — the interpreter would need to re-implement Dart's continuation and type machinery. *[Inference.]*
- **Whole-app virtualization** — ruled out by performance/size on any non-trivial app. *[Inference from §7-perf data.]*

### 7.4 Unavoidable limitations (cannot realistically be overcome)

- **No provable secrecy** (Barak et al.). *[Fact.]*
- **Generic devirtualization will eventually recover small arithmetic handlers** (Syntia-class). Diversity raises cost; it does not create a wall. *[Fact.]*
- **The interpreter is visible** in the AOT snapshot (Blutter). Security rests on bytecode opacity + handler cost, not on hiding the VM. *[Inference.]*

---

## 8. Technical Limitations

### 8.1 Theoretical

Barak et al. (2001) proved that **general virtual-black-box obfuscation is impossible** even under weak formalizations: there exist families of functions for which any program computing the function leaks a property that oracle access would not. *[Fact; https://eprint.iacr.org/2001/069, https://www.wisdom.weizmann.ac.il/~oded/PS/obf3.pdf.]* The theoretically secure notion, **indistinguishability obfuscation (iO)**, exists in candidate constructions but is far from practical, and Bitansky et al. (CRYPTO 2014) show iO for general circuits even *implies* strong VBB impossibility results. *[Fact; https://www.iacr.org/archive/crypto2014/86160238/86160238.pdf.]* Mahmoody et al. (TCC 2016) extend impossibility to idealized models. *[Fact; https://www.iacr.org/archive/tcc2016a/95620016/95620016.pdf.]*

**Consequence for Refractor** *[Inference]*: virtualization is a *cost-raising economic measure* in the MATE model, and must be sold and measured as such — "N× analyst-hours / M× tool-cost", never "cannot be recovered".

### 8.2 Platform

- No computed goto / labels-as-values → no classic threaded dispatch. *[Fact/Inference.]*
- No runtime code generation in AOT → no self-modifying code; only data-level dynamic decoding. *[Inference.]*
- AOT optimizer may *simplify* synthesized handlers, eroding potency unless actively resisted. *[Hypothesis — must verify.]*
- Kernel verifier + type system constrain what can be synthesized; everything injected must be well-typed. *[Fact.]*
- SDK-snapshot coupling: the vendored kernel is pinned to 3.11.3; the synthesized code and binary format track the SDK, so maintenance cost recurs each SDK bump. *[Fact.]*

### 8.3 Performance and size

Published measurements *[Fact, with the caveat that none is Dart-specific and configurations differ]*:

- WebAssembly study: Tigress virtualization grew file size ~53% and dropped throughput to ~63% of original. (https://arxiv.org/pdf/2403.15197)
- XuanJia paper: a Tigress virtualizer slowed execution **120×–337×** vs native; commercial binary protectors **2,485×–36,431×**. (Preprint, https://arxiv.org/pdf/2601.10261 — not independently verified by me.)
- Embedded-device study (OLLVM + Tigress): up to **~5× execution time and energy**. (https://www.amrita.edu/publication/a-framework-for-evaluation-of-software-obfuscation-tools-for-embedded-devices/)

**Consequence** *[Inference]*: only cold or rarely-hot, security-critical fragments are viable candidates. A Flutter frame budget (16.6 ms at 60 fps) makes virtualizing anything on the render/build hot path untenable.

### 8.4 Attack resistance is relative, and decays

Syntia recovered >94% of VMProtect/Themida arithmetic handlers in 2017; the field has advanced (Xyntia, Pushan, LLM agents) since. *[Fact / Fact-they-exist.]* Any resistance figure Refractor claims must be dated and tied to a specific attacker tool + configuration.

---

## 9. Open Research Questions

1. **Does Dart's AOT optimizer preserve or erode synthesized handler complexity?** Specifically, do `@pragma('vm:never-inline')` and opaque invariants survive to the snapshot, as seen through Blutter? *[Verify — this gates the entire approach's value.]*
2. **What is the realistic performance curve** for a `switch`-based `int`/`bool` stack VM in AOT Dart, as a function of bytecode length and MBA hardening? No Dart-specific numbers exist in the literature.
3. **Switch-loop vs closure/function dispatch table in AOT:** which is stealthier against Blutter, and does AOT devirtualize the indirect calls (collapsing the table)?
4. **Can non-linear MBA on Dart 64-bit `int` meaningfully raise synthesis/SMT cost** after the AOT optimizer runs, given that linear MBA is now routinely solved and compilers shrink MBA?
5. **How much does per-function ISA randomization + superoperators actually degrade** a Syntia/Xyntia-style attack on Dart handlers (as opposed to C/x86)?
6. **What subset of Dart is worth virtualizing** before interpreter size/complexity outweighs the benefit — i.e., where is the knee of the value/cost curve (int-only vs +strings vs +tagged objects)?
7. **Measured LLM-RE cost delta:** does stacking virtualization + MBA + rename + string-encrypt reproduce the "universal failure against combined obfuscation" result for Dart, and by how much does it raise cost for *assisted* (LLM + Blutter) attackers?
8. **Semantic-equivalence assurance:** what validation (differential testing, kernel verifier, property tests) is sufficient to trust that a virtualized function is behaviour-preserving across Dart's integer/overflow/exception edge cases?

### Claims requiring independent verification

- The XuanJia (2601.10261) and Pushan (2603.18355) preprints — **I have not read the full papers**; their figures are cited as reported, not verified.
- The Elastic "cost up to ~4×" figure was reached only via a third-party mirror — **verify against the original Elastic Security Labs publication**.
- CoDiver instruction-set-randomization claims come from a search summary only — **no primary URL obtained**.
- The "81–98% indirect-branch misprediction" figure is from a 2006 report citing Ertl & Gregg; it concerns C switch interpreters on then-current CPUs and **may not reflect modern branch predictors** (a Rust-internals discussion disputes how large the gap remains).

---

## 10. Proposed Validation Experiments

These are *investigations to de-risk the approach*, not an implementation plan. Each is small and answers a specific open question.

**E1 — Minimal injected interpreter survives AOT (answers Q1, Q3).**
Hand-synthesize (or hand-write in Dart, then study its kernel) a trivial `switch`-loop VM executing ~10 integer opcodes for one arithmetic function; compile a Flutter release build; inspect `libapp.so` with Blutter. *Measure:* is the dispatch loop present and recognizable? Did AOT inline/collapse handlers? Is the bytecode a visible data array? *Decision gate:* if AOT flattens it back to the original arithmetic, the whole approach needs rethinking.

**E2 — Performance envelope (answers Q2).**
Benchmark the E1 VM vs the native function across bytecode lengths and with/without MBA handler hardening. *Measure:* slowdown factor, size delta. *Output:* a Dart-specific cost curve to set the "surgical scope" policy.

**E3 — Dispatch comparison (answers Q3).**
Build switch-loop vs function-table variants of the same VM. *Measure:* perf delta; and, via Blutter, structural recognizability of each.

**E4 — MBA durability under AOT (answers Q4).**
Apply non-linear MBA to handler arithmetic; compile; recover handler pseudo-code via Blutter; attempt simplification with an off-the-shelf MBA simplifier (e.g., GAMBA-class) and/or an SMT solver. *Measure:* does AOT pre-simplify the MBA? does the simplifier recover the original op?

**E5 — Attack-cost sanity check (answers Q5, Q7).**
Take a representative function (e.g., a toy license check), produce (a) plain, (b) rename+string-encrypt, (c) +virtualized, (d) +virtualized+MBA. Give each to (i) a Blutter-assisted human and (ii) an LLM agent. *Measure:* time/tokens/success to recover the predicate. This directly tests the stated LLM-resistance motivation.

**E6 — Semantic-equivalence harness (answers Q8).**
Differential-test virtualized vs original across randomized inputs including integer-overflow and exception edge cases; run the kernel verifier on all outputs. *Output:* a reusable correctness gate any future pass must pass.

**Suggested ordering:** E1 is the gate — if handlers do not survive AOT recognizably, stop. Then E2/E6 (viability + correctness), then E3/E4 (hardening), then E5 (the headline cost-vs-attacker result).

---

## 11. References

Primary sources and specifications are preferred; where a source is vendor-authored, a preprint, or reached only via mirror, it is flagged inline above.

**Commercial virtualizers (vendor-authored)**
- VMProtect user manual — https://vmpsoft.com/vmprotect/user-manual
- VMProtect overview — https://vmpsoft.com/vmprotect/overview
- Oreans Code Virtualizer — https://oreans.com/CodeVirtualizer.php
- Oreans Themida — https://www.oreans.com/Themida.php

**Academic / source-level virtualization**
- Tigress — https://tigress.wtf/ ; virtualize transform — https://tigress.wtf/virtualize.html ; recipes — https://tigress.wtf/recipes.html
- Collberg et al., "Manufacturing cheap, resilient, and stealthy opaque constructs" (POPL'98) — https://experts.arizona.edu/en/publications/manufacturing-cheap-resilient-and-stealthy-opaque-constructs/
- Blazytko & Schloegel, "The Next Generation of Virtualization-based Obfuscators" (Recon 2022 / HITB AMS 2023) — https://conference.hitb.org/hitbsecconf2023ams/session/the-next-generation-of-virtualization-based-obfuscators/
- Naiqian Zhang, "Virtual Machine, Real Threats…" (PhD dissertation, UNH, 2025) — https://scholars.unh.edu/dissertation/2946
- XuanJia: virtualization-based binary obfuscator (preprint, not independently verified) — https://arxiv.org/pdf/2601.10261

**Devirtualization / attacks**
- Rolles, "Unpacking Virtualization Obfuscators" (USENIX WOOT'09) — https://static.usenix.org/events/woot09/tech/full_papers/rolles.pdf
- Blazytko et al., "Syntia: Synthesizing the Semantics of Obfuscated Code" (USENIX Security 2017) — https://www.usenix.org/conference/usenixsecurity17/technical-sessions/presentation/blazytko ; Black Hat Asia 2018 whitepaper — https://i.blackhat.com/briefings/asia/2018/asia-18-Blazytko-Breaking-State-Of-The-Art-Binary-Code-Obfuscation-Via-Program-Synthesis-wp.pdf
- "VMHunt: A Verifiable Approach to Partially-Virtualized Binary Code Simplification" (CCS'18) — https://faculty.ist.psu.edu/wu/papers/vmhunt-ccs18.pdf
- "Pushan" trace-free devirtualization (preprint, not independently verified) — https://www.alphaxiv.org/abs/2603.18355v1
- back.engineering obfuscation/devirtualization write-ups (practitioner) — https://back.engineering/tags/obfuscation/
- ANY.RUN, VMProtect/Themida malware analysis — https://any.run/cybersecurity-blog/vmprotect-themida-malware-analysis/

**MBA / opaque predicates**
- "MBA-Blast" (USENIX Security 2021) — https://par.nsf.gov//servlets/purl/10318190
- GAMBA / equality-saturation MBA (ERCIM News) — https://ercim-news.ercim.eu/en139/special/generating-mixed-boolean-arithmetic-expressions-through-equality-saturation

**Theory of obfuscation**
- Barak et al., "On the (Im)possibility of Obfuscating Programs" (eprint 2001/069) — https://eprint.iacr.org/2001/069 ; full version — https://www.wisdom.weizmann.ac.il/~oded/PS/obf3.pdf
- Bitansky et al., CRYPTO 2014 — https://www.iacr.org/archive/crypto2014/86160238/86160238.pdf
- Mahmoody et al., TCC 2016 — https://www.iacr.org/archive/tcc2016a/95620016/95620016.pdf

**Interpreter dispatch / performance**
- TCD-CS-2006-51, threaded code & dispatch (citing Ertl & Gregg) — https://publications.scss.tcd.ie/tech-reports/reports.06/TCD-CS-2006-51.pdf
- Tigress virtualization overhead in a WebAssembly setting — https://arxiv.org/pdf/2403.15197
- Obfuscation cost on embedded devices (OLLVM/Tigress) — https://www.amrita.edu/publication/a-framework-for-evaluation-of-software-obfuscation-tools-for-embedded-devices/

**Dart / Flutter reverse engineering**
- B(l)utter — Reversing Flutter Applications (HITB 2023 slides) — https://conference.hitb.org/hitbsecconf2023hkt/materials/
- Guardsquare, "The Current State & Future of Reverse Engineering Flutter Apps" — https://guardsquare.com/blog/current-state-and-future-of-reversing-flutter-apps
- OWASP MASTG, "Reverse Engineering Flutter Applications" — https://mas.owasp.org/MASTG/techniques/android/MASTG-TECH-0112
- Dart SDK, "Remove bytecode mode from the VM" (Oct 2020) — https://dart.googlesource.com/sdk.git/+/7588ed86deef16b81325d651b33ecf58a2f30d4a%5E%21/

**LLM-assisted reverse engineering**
- Tkachenko et al., LLMs vs assembly obfuscation (2025) — https://arxiv.org/html/2504.10557v1
- LLM-based decompilation survey/eval (2025) — https://arxiv.org/html/2505.19887v1
- "The Cost of Understanding: LLM-Driven RE vs Iterative LLM Obfuscation" (mirror; verify against Elastic original) — https://www.hendryadrian.com/?p=99697

---

*End of research phase. Architecture, interfaces, and implementation planning are deliberately out of scope for this document and should follow only after the Section 10 gate experiments (especially E1) are run.*
