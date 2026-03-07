# Copilot Chat Conversation Export: Usage of cfg package in compilation

**User:** @yardexx
**Thread URL:** https://github.com/copilot/c/aad3b555-6c9f-4f3e-b6f0-1c94dcea2508

## @yardexx

In what part of compilation is cfg package used?

## Copilot

The `cfg` package is used in the **middle/end of an experimental native compilation pipeline**, not in the regular Dart front end parsing stage.

Most directly:

- `pkg/cfg/README.md` says it defines a **control-flow graph (CFG) intermediate representation** for Dart programs plus **optimization passes**. Its structure is:
  - `front_end/` = translation from **Kernel AST to CFG**
  - `ir/` = CFG/SSA IR
  - `passes/` = optimization passes citeturn0commentaryto=multi_tool_use.parallel0

- In `pkg/native_compiler/lib/compilation_set.dart`, the native compiler imports:
  - `package:cfg/front_end/ast_to_ir.dart`
  - `package:cfg/front_end/recognized_methods.dart`
  - `package:cfg/ir/flow_graph.dart`  
  which shows `cfg` is used when the native compiler **lowers Kernel AST into CFG IR** before later code generation. citeturn0commentaryto=multi_tool_use.parallel0

- In `pkg/native_compiler/lib/configuration.dart`, the native compiler imports:
  - `package:cfg/ir/ssa_computation.dart`
  - `package:cfg/passes/constant_propagation.dart`
  - `package:cfg/passes/control_flow_optimizations.dart`
  - `package:cfg/passes/simplification.dart`
  - `package:cfg/passes/value_numbering.dart`  
  which indicates `cfg` is used for the **optimization/SSA phase** of compilation. citeturn0commentaryto=multi_tool_use.parallel0

- The pipeline abstraction in `pkg/cfg/lib/passes/pass.dart` explicitly describes itself as a **compiler pipeline** over a `FlowGraph`, with passes run one after another and graph checking after each pass. citeturn0commentaryto=multi_tool_use.parallel0

So the short answer is:

**`cfg` is used after Kernel AST is available, during lowering to CFG IR and during SSA/optimization passes, primarily inside `pkg/native_compiler`'s compilation pipeline.** It appears to be part of an **experimental native compiler backend path**, rather than the main front-end parser/type-checker stage. citeturn0commentaryto=multi_tool_use.parallel0

A few relevant snippets:

````markdown name=pkg/cfg/README.md url=https://github.com/dart-lang/sdk/blob/fde3828514bead9dd1c35185a565cd638db12ab8/pkg/cfg/README.md#L1-L20
This package defines control flow graph (CFG) intermediate representation of
Dart programs and optimization passes performed on CFG.

This package is intended to be used only by Dart compiler(s) in the Dart SDK.

Structure of the package:
```
  front_end/  # Translation from kernel AST to CFG.
  ir/         # CFG/SSA IR and computation of its properties.
  passes/     # Optimization passes.
  utils/      # General-purpose utilities.
```
````

```dart name=pkg/native_compiler/lib/compilation_set.dart url=https://github.com/dart-lang/sdk/blob/fde3828514bead9dd1c35185a565cd638db12ab8/pkg/native_compiler/lib/compilation_set.dart#L1-L22
import 'package:cfg/front_end/ast_to_ir.dart';
import 'package:cfg/front_end/recognized_methods.dart';
import 'package:cfg/ir/flow_graph.dart';
import 'package:cfg/ir/functions.dart';
```

```dart name=pkg/native_compiler/lib/configuration.dart url=https://github.com/dart-lang/sdk/blob/fde3828514bead9dd1c35185a565cd638db12ab8/pkg/native_compiler/lib/configuration.dart#L1-L18
import 'package:cfg/ir/functions.dart';
import 'package:cfg/ir/ssa_computation.dart';
import 'package:cfg/passes/constant_propagation.dart';
import 'package:cfg/passes/control_flow_optimizations.dart';
import 'package:cfg/passes/pass.dart';
import 'package:cfg/passes/simplification.dart';
import 'package:cfg/passes/value_numbering.dart';
```

```dart name=pkg/cfg/lib/passes/pass.dart url=https://github.com/dart-lang/sdk/blob/fde3828514bead9dd1c35185a565cd638db12ab8/pkg/cfg/lib/passes/pass.dart#L1-L58
/// Base class for a pass in the compiler pipeline.
abstract base class Pass {
  final String name;
  ...
}

/// Sequence of passes.
///
/// Provides detailed crash reporting and
/// performs flow graph checking after each pass.
class Pipeline {
```

Note: the code-search results may be incomplete because the search tool is capped. You can inspect more matches in GitHub code search here:

```text name=github-code-search.txt
https://github.com/search?q=repo%3Adart-lang%2Fsdk+%28%22package%3Acfg%22+OR+%22cfg%2F%22%29&type=code
```

If you want, I can next trace the exact call chain in `pkg/native_compiler` from **Kernel input → CFG creation → optimization passes → code generation**.

## @yardexx

Are those passes applied when I call "dart compile kernel"?

## Copilot

No — **those `cfg` passes are not what `dart compile kernel` applies**.

`dart compile kernel` produces a **Kernel `.dill`** file, i.e. a serialized **Kernel AST**, not native code. The docs describe the `kernel` subcommand as packaging the program into a portable file containing the **binary form of the abstract syntax tree (Kernel AST)**. That means it stops at the Kernel representation rather than going through the experimental CFG optimization/codegen pipeline. citeturn0commentaryto=multi_tool_use.parallel0

By contrast, the `cfg` package is wired into `pkg/native_compiler`, where it is used for:
- lowering **Kernel AST → CFG IR**
- computing **SSA**
- running optimization passes like constant propagation, simplification, control-flow optimizations, and value numbering. citeturn0commentaryto=multi_tool_use.parallel0turn0commentaryto=multi_tool_use.parallel1

You can see that directly here:

```dart name=pkg/native_compiler/lib/configuration.dart url=https://github.com/dart-lang/sdk/blob/fde3828514bead9dd1c35185a565cd638db12ab8/pkg/native_compiler/lib/configuration.dart#L1-L25
import 'package:cfg/ir/functions.dart';
import 'package:cfg/ir/ssa_computation.dart';
import 'package:cfg/passes/constant_propagation.dart';
import 'package:cfg/passes/control_flow_optimizations.dart';
import 'package:cfg/passes/pass.dart';
import 'package:cfg/passes/simplification.dart';
import 'package:cfg/passes/value_numbering.dart';
...
import 'package:native_compiler/passes/lowering.dart';
import 'package:native_compiler/passes/reorder_blocks.dart';
```

And the `cfg` package README says its role is CFG IR plus optimization passes:

````markdown name=pkg/cfg/README.md url=https://github.com/dart-lang/sdk/blob/fde3828514bead9dd1c35185a565cd638db12ab8/pkg/cfg/README.md#L1-L14
This package defines control flow graph (CFG) intermediate representation of
Dart programs and optimization passes performed on CFG.

Structure of the package:
```
  front_end/  # Translation from kernel AST to CFG.
  ir/         # CFG/SSA IR and computation of its properties.
  passes/     # Optimization passes.
```
````

So the compilation stages are roughly:

- **`dart compile kernel`**: Dart source → front end → **Kernel AST (`.dill`)**
- **experimental native compiler path**: Kernel AST → **CFG IR** → **SSA/optimization passes** → native code/image

So the answer is:

**`dart compile kernel` does not run those CFG passes; it emits Kernel before that experimental CFG/native-compiler pipeline would be used.**

One caveat: code-search results may be incomplete because the search tool is capped, but the evidence found is enough to answer confidently. If you want to inspect more, here are GitHub code search links:

```text name=github-code-search-kernel.txt
https://github.com/search?q=repo%3Adart-lang%2Fsdk+%28%22dart+compile+kernel%22+OR+%22kernel+snapshot%22+OR+%22compile+kernel%22%29&type=code
```

```text name=github-code-search-cfg.txt
https://github.com/search?q=repo%3Adart-lang%2Fsdk+%22package%3Acfg%2F%22&type=code
```

If you want, I can also answer the follow-up: **which optimizations *are* performed before writing a `.dill` during `dart compile kernel`?**

## @yardexx

I am writing obfuscator. I need somehow to bypass optimizations (by either reverting them or bypassing completely)

## Copilot

If your target is **`dart compile kernel`**, then the good news is:

**you probably do not need to fight the `pkg/cfg` optimizations at all**, because those CFG/SSA passes are not the pipeline used to produce the `.dill` file. The `.dill` is Kernel IR, so your obfuscator should focus on **Kernel/front_end transformations**, not `pkg/cfg`. citeturn0commentaryto=multi_tool_use.parallel0turn0commentaryto=multi_tool_use.parallel1

So the practical answer is:

## What to target instead

For a Kernel-based obfuscator, the right insertion points are usually:

1. **Before Kernel is serialized**
   - transform the Kernel AST in memory
   - then write the modified `.dill`

2. **After generating `.dill`**
   - load the `.dill`
   - rewrite the Kernel component
   - reserialize it

That is much easier than trying to “undo” backend optimizations.

## What “optimizations” are still relevant

Even if CFG passes are irrelevant, you may still run into **front-end / Kernel-level canonicalization or lowering** that affects obfuscation, such as:
- constant folding
- desugaring/lowering
- tree shaking in later compilers
- name canonicalization / metadata handling
- inlining or type-flow-style optimizations in later backends, depending on what eventually consumes the Kernel

So the key question is:

### Are you obfuscating for:
- **`.dill` output only**, or
- **final executable / AOT / JS output**?

Because the strategy differs:

### If you only care about obfuscating the `.dill`
Then modify Kernel directly and emit it. No need to bypass `cfg`.

### If you care that the obfuscation survives later compilation
Then you need transformations that are **semantics-preserving but optimization-resistant**. In that case, instead of reverting optimizations, you usually:
- insert opaque predicates
- block constant folding
- prevent easy inlining
- hide string constants
- split expressions across side-effect boundaries
- use constructs the optimizer must preserve

## Best approach

For an obfuscator, **bypassing** optimizations is usually better than **reverting** them.

Why:
- reverting is brittle
- many optimizations lose source-level intent permanently
- bypassing at the right IR level is simpler and more stable

## Recommended plan

### Option A: Build a Kernel-to-Kernel obfuscator
Pipeline:
- source → front end → Kernel component
- obfuscate Kernel
- serialize `.dill`

### Option B: Patch the front end / compiler pipeline
Add your transform right before Kernel writing.

### Option C: Post-process `.dill`
Read the component, rewrite names/control flow/constants, write back.

## What not to do first

I would **not** start by patching `pkg/cfg` unless your real target is the experimental `native_compiler`.

## Concrete advice

If your aim is:
- **identifier renaming** → do it in Kernel
- **control-flow obfuscation** → also do it in Kernel, but carefully
- **string obfuscation** → Kernel or later IR
- **anti-optimization behavior** → design transforms that survive later compilers rather than disabling optimizers globally

## Important caveat

If you make Kernel intentionally weird, later consumers may:
- reject invalid IR
- normalize it
- optimize it away
- break source maps / stack traces / debugging

So you want **valid, conservative Kernel rewrites**.

## My recommendation

Given what you asked, I’d do this:

1. Ignore `pkg/cfg`
2. Find the Kernel serialization path for `dart compile kernel`
3. Insert a **Kernel AST transformation pass** before serialization
4. Make the transforms optimization-resistant rather than trying to disable optimizers

If you want, I can next help with one of these very concretely:

1. **Find the exact file/function in `dart-lang/sdk` where `dart compile kernel` writes the `.dill`**
2. **Design a Kernel-to-Kernel obfuscation pass**
3. **List which Kernel-level rewrites tend to survive later optimization**
4. **Show how to patch the SDK to add an obfuscation hook**

## @yardexx

but. what happens when I use that dill further in compilation? (building .exe for example)?

## Copilot

Yes — **later compilation stages can still optimize your obfuscated `.dill` away**.

A `.dill` is just **Kernel IR**, not a “frozen final form.” When you later use that `.dill` to build something like an executable, the consumer compiler/backend can perform its own analysis and optimization on the Kernel program before generating machine code or other output. So:

- obfuscating at the `.dill` level **does preserve your transformed program as input**
- but it does **not guarantee** the same structure survives into the final `.exe`

## Practically, what this means

If you do:

- source → `dart compile kernel` → obfuscated `.dill`
- then `.dill` → executable

the later compiler may still:
- fold constants
- inline functions
- eliminate dead branches
- simplify control flow
- deduplicate constants
- remove unused declarations
- lower constructs into cleaner forms

So if your obfuscation relies on:
- fake branches
- arithmetic disguises that are still compile-time computable
- wrapper functions that are obviously inlineable
- unreachable junk code

then a later backend may erase much of it.

## Good mental model

Think of `.dill` as:

- **portable compiler IR**
- not final artifact
- still subject to optimization by downstream compilers

## So what survives best?

Usually these survive better:

- **identifier renaming**
  - often survives unless symbols are discarded or remapped later
- **string/data obfuscation with runtime decoding**
  - survives if decoding has observable runtime behavior
- **transformations involving real side effects**
  - optimizers must be more conservative
- **indirection through dynamic features**
  - harder to fold away, though often slower

These survive poorly:

- pure constant expressions disguised with arithmetic
- dead code
- branches with statically known conditions
- trivial wrapper methods
- obviously redundant temporaries

## If your goal is final executable obfuscation

Then you should design transformations to be **optimization-resistant**, not just “different in Kernel.”

Typical techniques:
- ensure computations depend on runtime values
- introduce observable side effects where legal
- avoid patterns that make values compile-time constant
- avoid creating obviously dead paths
- encode strings/tables and decode lazily at runtime
- use boundaries that discourage inlining/simplification

## Best strategy by goal

### Goal: obfuscated `.dill`
Kernel transform is enough.

### Goal: obfuscated final `.exe`
Kernel transform is only the first step.
You must assume later optimization will rewrite it.

### Goal: preserve specific obfuscated control flow in final binary
Then you need transforms designed specifically to survive backend optimization, or you need to patch/disable the downstream optimizer in the compiler producing the `.exe`.

## Short answer

**What happens when you use the `.dill` further?**  
It gets treated as compiler input, and **more optimizations can happen**, so your obfuscation may be partially or heavily reduced unless it is designed to survive those later stages.

If you want, I can next give you a **ranked list of obfuscation techniques for Dart/Kernel that are most likely to survive later executable compilation**.

## @yardexx

tell me

## Copilot

Here’s a practical ranking for **Dart/Kernel obfuscation that’s likely to survive later compilation to an executable**.

## Tier 1 — usually survives well

### 1. Identifier renaming
Rename:
- classes
- methods
- fields
- locals
- parameters
- library-private symbols where legal

Why it survives:
- later optimizers may remove symbols, but they generally do **not reconstruct meaningful original names**
- this is the safest and cheapest form of obfuscation

Best for:
- making decompiled output harder to read

Weakness:
- does not hide logic by itself

---

### 2. String obfuscation with runtime decoding
Instead of storing plaintext strings, store:
- encoded byte arrays
- chunked pieces
- xor/add transformed values
- generated-at-runtime strings

Why it survives:
- if decoding happens at runtime, optimizer usually cannot replace it with the original plaintext unless everything is still statically computable

Best for:
- API keys, messages, protocol names, suspicious literals

Weakness:
- if your decoder and encoded data are fully constant and simple, some optimizers may partially fold them

**Rule:** make decoding depend on runtime state or at least on nontrivial control/data flow.

---

### 3. Indirection that has real runtime semantics
Examples:
- lookup tables
- dispatch through maps/arrays
- computed selectors
- extra function boundaries that are not trivial/pure

Why it survives:
- backend can simplify only so much if behavior remains dynamic

Best for:
- hiding call relationships
- flattening obvious control structure into dispatcher-like execution

Weakness:
- may cost performance

---

## Tier 2 — can survive if done carefully

### 4. Control-flow flattening
Turn normal structured flow into:
- state machine
- dispatcher loop
- switch-driven control states

Why it can survive:
- if the state transitions depend on runtime values, compiler can’t fully reconstruct original flow

Why it often fails:
- if states are static and obvious, optimizer may simplify large parts of it

Best practice:
- avoid a purely compile-time state progression
- do not make the whole dispatcher obviously reducible

---

### 5. Wrapper methods / call indirection
Turn:
- direct calls into wrappers
- field accesses into accessor functions
- operations into helper calls

Why it can survive:
- if wrappers are nontrivial, dynamic, or externally visible

Why it often fails:
- trivial wrappers get inlined or removed

Best practice:
- wrappers need enough semantic weight that the optimizer cannot erase them cheaply

---

### 6. Data transformation / table encoding
Hide constants, switch tables, or object layouts behind encoded forms.

Why it survives:
- runtime decoding/use patterns often remain necessary

Best for:
- enums, protocol data, lookup constants, resource strings

Weakness:
- static analyzers can sometimes still recover them

---

## Tier 3 — weak unless combined with stronger tricks

### 7. Arithmetic disguises
Examples:
- replace `42` with `((10 * 5) - 8)`
- boolean expressions disguised with math

Why weak:
- if it is statically computable, it gets folded

Use only when:
- expression depends on runtime inputs or hidden state

---

### 8. Opaque predicates
Example:
- conditions that are always true/false in practice but hard to prove

Why weak in managed languages:
- many “opaque” predicates are not actually opaque to compiler analysis

Can work if:
- tied to runtime state, object identity, exceptions, or side effects

Bad version:
- pure arithmetic predicate over constants

---

### 9. Junk/dead code insertion
Why weak:
- dead code elimination destroys it quickly

Only useful if:
- it is not provably dead
- it is entangled with observable behavior

---

## Tier 4 — usually not worth relying on

### 10. Pure no-op structure changes
Examples:
- extra locals
- redundant assignments
- obviously unused branches
- pointless temp variables

These are the first things optimizers clean up.

---

# Best combo for surviving later compilation

If your goal is **final executable obfuscation**, the strongest practical combo is:

1. **identifier renaming**
2. **string/data encoding with runtime decoding**
3. **selected indirection**
4. **careful control-flow flattening**
5. **avoid anything statically computable**

That gives you the best tradeoff of:
- resilience
- correctness
- survivability through optimization

# Design rules to survive optimization

## Rule 1: Depend on runtime state
If everything is derivable from constants, it will be simplified.

Use:
- runtime inputs
- object identity
- heap state
- exception behavior
- environment-derived values
- values loaded from encoded data

## Rule 2: Preserve observable effects
Optimizers are conservative around:
- side effects
- exceptions
- unknown aliasing
- dynamic dispatch

## Rule 3: Avoid obviously pure wrappers
A helper like `int f(int x) => x + 1;` is optimizer food.

## Rule 4: Don’t rely on dead code
If it doesn’t affect output, it won’t survive.

## Rule 5: Prefer data obfuscation over fake control complexity
Data hiding usually survives better than artificial branch noise.

# Recommended ranking

For your use case, I’d rank them like this:

1. **Identifier renaming**
2. **String obfuscation with runtime decode**
3. **Constant/data table encoding**
4. **Call indirection with nontrivial semantics**
5. **Control-flow flattening**
6. **Opaque predicates tied to runtime state**
7. **Arithmetic disguises**
8. **Dead code / junk code**

# Concrete advice for Dart/Kernel

If you’re building a Kernel-level obfuscator, I would start with:

- renaming symbols
- replacing string literals with encoded representations + decoder calls
- wrapping selected call sites in indirect dispatch
- optionally flattening only high-value functions

I would **not** start with:
- junk code
- arithmetic-only disguises
- massive everywhere flattening

Those tend to either get optimized away or destroy performance.

# Important tradeoff

The more optimization-resistant your obfuscation is, the more likely it is to:
- hurt performance
- increase code size
- complicate debugging/crash reporting
- trigger edge cases in later compilers

So target only:
- sensitive functions
- sensitive strings
- sensitive APIs

not the whole program uniformly.

If you want, I can next give you one of these:

1. a **Kernel-level implementation plan** for these techniques  
2. a **specific “survives AOT better” string obfuscation pattern**  
3. a **control-flow flattening pattern that is harder to optimize away**  
4. a **list of Dart constructs that backend optimizers are most likely to simplify**

## @yardexx

what passes are in cfg so I can avoid implementing "antipasses"?

## Copilot

In the current `cfg`-based pipeline I found, the main `cfg` passes you’d need to think about are:

1. **SSAComputation**
2. **ValueNumbering**  
   - configured with **Simplification**
3. **ConstantPropagation**
4. **ControlFlowOptimizations**

And the pipeline also inserts **FlowGraphChecker** before and after each pass as a verifier, though that one is not an optimizer. citeturn0commentaryto=multi_tool_use.parallel1turn0commentaryto=multi_tool_use.parallel0

The concrete pass list is here:

```dart name=pkg/native_compiler/lib/configuration.dart url=https://github.com/dart-lang/sdk/blob/fde3828514bead9dd1c35185a565cd638db12ab8/pkg/native_compiler/lib/configuration.dart#L91-L144
return Pipeline([
  SSAComputation(),
  ValueNumbering(simplification: Simplification()),
  ConstantPropagation(),
  ControlFlowOptimizations(),
  Lowering(functionRegistry, objectLayout),
  ReorderBlocks(backEndState),
  LinearScanRegisterAllocator(backEndState, constraints),
  RegisterAllocationChecker(backEndState, constraints),
  createCodeGenerator(backEndState, functionRegistry),
]);
```

If you only mean **passes from the `cfg` package itself**, then the relevant ones are:

- `SSAComputation` — converts the flow graph into SSA form by removing locals and inserting `Phi`/`Parameter` nodes. citeturn0commentaryto=multi_tool_use.parallel0
- `Simplification` — canonicalization + constant folding. citeturn0commentaryto=multi_tool_use.parallel0
- `ValueNumbering` — dominator-based common-subexpression/value deduplication, optionally running `Simplification` first. citeturn0commentaryto=multi_tool_use.parallel0
- `ConstantPropagation` — sparse conditional constant propagation plus unreachable code elimination. citeturn0commentaryto=multi_tool_use.parallel0
- `ControlFlowOptimizations` — removes redundant gotos/branches and merges blocks. citeturn0commentaryto=multi_tool_use.parallel0
- `FlowGraphChecker` — integrity checker, not an optimization pass. citeturn0commentaryto=multi_tool_use.parallel1

A useful mental grouping:

## Structural / normalization
- **SSAComputation**

## Local simplification
- **Simplification**

## Redundancy elimination
- **ValueNumbering**
- **ConstantPropagation**

## CFG cleanup
- **ControlFlowOptimizations**

## Validation
- **FlowGraphChecker**

So if you want to avoid writing unnecessary “antipasses,” these are the main things you’d design against:

- **constant folding** → `Simplification`
- **common subexpression elimination / dedup** → `ValueNumbering`
- **constant propagation + unreachable code elimination** → `ConstantPropagation`
- **branch/goto/block cleanup** → `ControlFlowOptimizations`
- **SSA normalization** → `SSAComputation`

Important caveat: the code-search results may be incomplete because the search tool is capped, but this pipeline definition is direct and load-bearing. For more matches, you can inspect GitHub code search here:

```text name=github-code-search-cfg-passes.txt
https://github.com/search?q=repo%3Adart-lang%2Fsdk+path%3Apkg%2Fcfg%2Flib+%22extends+Pass%22&type=code
```

```text name=github-code-search-pipeline.txt
https://github.com/search?q=repo%3Adart-lang%2Fsdk+path%3Apkg%2Fnative_compiler%2Flib+%22Pipeline%28%5B%22&type=code
```

If you want, I can next turn this into a **“don’t bother fighting these / do fight these” table** for obfuscation design.

## @yardexx

Yes, exactly what I was heading for. You're reading my mind.

## Copilot

Here’s the table you want.

# Which `cfg` passes are worth fighting?

| Pass | What it does | Will it kill naive obfuscation? | Should you design against it? | Notes |
|---|---|---:|---:|---|
| `SSAComputation` | Rewrites locals into SSA, inserts `Phi`s, removes `LoadLocal`/`StoreLocal` | Medium | **No**, usually | Mostly structural normalization, not “deobfuscation” |
| `Simplification` | Canonicalization + constant folding | High | **Yes** | One of the main enemies |
| `ValueNumbering` | Deduplicates equivalent idempotent computations, can run simplification first | High | **Yes** | Kills repeated disguised expressions |
| `ConstantPropagation` | Propagates constants, removes unreachable code | Very high | **Yes** | Biggest threat to fake branches / opaque predicates |
| `ControlFlowOptimizations` | Removes redundant branches/gotos, merges blocks | High | **Yes** | Kills empty/degenerate CFG tricks |
| `FlowGraphChecker` | Verifies graph integrity | 0 | **No** | Not an optimizer; just makes invalid tricks crash/assert |

So the short answer:

## Do not waste time on antipasses for:
- `SSAComputation`
- `FlowGraphChecker`

## Do design obfuscation to survive:
- `Simplification`
- `ValueNumbering`
- `ConstantPropagation`
- `ControlFlowOptimizations`

---

# Practical interpretation

## 1. `SSAComputation`
What it destroys:
- reliance on local variable clutter
- fake temp-variable spaghetti
- store/load noise

What survives:
- actual semantic complexity
- runtime-dependent values
- encoded data and real dispatch

### Recommendation
Do **not** build obfuscation that depends on lots of meaningless locals. SSA will normalize that away conceptually.

---

## 2. `Simplification`
This is your first real enemy.

From the code:
- it does **constant folding**
- canonicalization
- phi simplification like replacing `phi(x, x, x)` with `x` citeturn0commentaryto=multi_tool_use.parallel0

It will destroy:
- constant arithmetic disguises
- statically known boolean tricks
- redundant equivalent forms
- trivial phi-based confusion

### Fight it?
**Yes. Definitely.**

### How to survive
- avoid purely constant expressions
- make values depend on runtime data
- avoid obvious canonical equivalents
- don’t use fake phi complexity

---

## 3. `ValueNumbering`
This one removes repeated equivalent computations.

From the code:
- it only works on **idempotent** instructions
- it can simplify first, then replace repeated instructions with prior ones citeturn0commentaryto=multi_tool_use.parallel0

It will destroy:
- repeated disguised expressions
- duplicate computation trees
- many “compute same thing three different ways” tricks if they simplify to same value/instruction shape

### Fight it?
**Yes.**

### How to survive
- avoid repeated pure/idempotent disguised computations
- introduce non-idempotence or observable differences
- vary shape enough that instructions don’t hash/compare equal

---

## 4. `ConstantPropagation`
This is probably the **main thing to care about**.

From the source:
- sparse conditional constant propagation
- also does **unreachable code elimination** citeturn0commentaryto=multi_tool_use.parallel0

It will kill:
- opaque predicates that are actually compile-time decidable
- dead branches
- fake state machines with constant states
- junk code behind statically false conditions
- values that become constant after propagation

### Fight it?
**Absolutely yes. Highest priority.**

### How to survive
- ensure branch conditions depend on runtime state
- avoid compile-time-known dispatcher values
- avoid deriving all “hidden” values from constants
- don’t make your obfuscation reducible by simple propagation

---

## 5. `ControlFlowOptimizations`
From the code:
- removes redundant gotos
- removes redundant branches when both sides collapse to same successor
- merges blocks citeturn0commentaryto=multi_tool_use.parallel0

It will destroy:
- empty basic block chains
- useless gotos
- if/else that actually go to same place
- trivial split/merge CFG noise

### Fight it?
**Yes, but only a little.**

### How to survive
- don’t build obfuscation out of empty block noise
- make branch structure semantically meaningful
- ensure different successors really matter
- avoid branch patterns that immediately rejoin identically

---

# What anti-pass work is mostly wasted?

## Wasted effort
### Fighting `SSAComputation`
Usually pointless because SSA conversion doesn’t really make the program less obfuscated in the way that matters. It mostly changes representation.

### Fighting `FlowGraphChecker`
Also pointless. If you “fight” this, you’re usually just making invalid IR.

---

# Best prioritization

If you want the highest return on effort:

## Priority 1
Design against:
- `ConstantPropagation`
- `Simplification`

## Priority 2
Then against:
- `ValueNumbering`

## Priority 3
Then:
- `ControlFlowOptimizations`

## Ignore
- `SSAComputation`
- `FlowGraphChecker`

---

# Technique-by-technique mapping

## Identifier renaming
Threatened by:
- basically none of these directly

Verdict:
- **safe**
- no antipass needed

---

## String obfuscation with runtime decode
Threatened by:
- `Simplification`
- `ConstantPropagation`

Only if:
- the decode is fully static / pure / constant-evaluable

Verdict:
- **good**, if runtime-dependent enough

---

## Arithmetic disguises
Threatened by:
- `Simplification`
- `ConstantPropagation`
- `ValueNumbering`

Verdict:
- **weak**, unless runtime-bound

---

## Opaque predicates
Threatened by:
- `ConstantPropagation`
- `Simplification`

Verdict:
- only good if genuinely opaque to compiler analysis

---

## Control-flow flattening
Threatened by:
- `ConstantPropagation`
- `ControlFlowOptimizations`

Verdict:
- can work, but state must not be compile-time-known

---

## Junk code
Threatened by:
- `ConstantPropagation`
- `ControlFlowOptimizations`

Verdict:
- mostly not worth it

---

## Repeated wrapper computations
Threatened by:
- `ValueNumbering`
- `Simplification`

Verdict:
- weak if pure and repetitive

---

# Your “don’t implement antipasses for this” checklist

## Don’t bother:
- fake local-variable clutter
- pointless load/store noise
- phi noise
- empty blocks
- redundant gotos
- statically false/true junk branches
- repeated pure disguised arithmetic

## Better to implement:
- runtime-dependent string/data decoding
- nontrivial indirection
- selective control-flow flattening with dynamic state
- symbol renaming
- transformations with observable runtime behavior

---

# One-sentence summary

If you want to avoid wasted effort, **treat `ConstantPropagation`, `Simplification`, `ValueNumbering`, and `ControlFlowOptimizations` as the real enemies; ignore `SSAComputation` and `FlowGraphChecker`.**

If you want, I can next make this even more useful as a **“obfuscation pattern → which cfg pass breaks it → how to harden it” matrix**.
