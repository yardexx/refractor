# Fresh Feature Opportunities For Refractor

**Status:** active
**Owner:** maintainers
**Last reviewed:** 2026-03-24
**Applies to:** post-`v0.2.0` product research
**Related:** [research-landscape.md](research-landscape.md), [research-trends-2026.md](research-trends-2026.md), [../features/future/rename-improvements.md](../features/future/rename-improvements.md), [../features/future/string-encrypt-improvements.md](../features/future/string-encrypt-improvements.md), [../roadmap/product-plan.md](../roadmap/product-plan.md)

## Goal

Identify feature directions that feel genuinely distinctive for Refractor in
2026, rather than re-listing the standard obfuscator menu of rename, string
encryption, and generic control-flow tricks.

This note is intentionally biased toward ideas that:

- fit a Dart kernel-level tool better than a post-compile wrapper
- respond to current reverse-engineering trends
- create product differentiation, not just checkbox parity
- can be reasoned about and tested incrementally

## What Already Exists Or Is Already On The Table

These are **not** the focus of this note because they are already shipped or
already captured elsewhere in the docs:

- rename foundation
- string encryption foundation
- crash-symbol workflows and symbolication
- name overloading
- string interpolation coverage
- multi-layer string encoding
- string array indirection
- misleading rename strategies
- annotation-based keep controls
- generic resistance testing

Also, ideas like "add control flow flattening" or "inject dead code" are only
interesting if Refractor gives them a Dart-specific twist. On their own they
read like table-stakes obfuscator features.

## External Signals That Matter

Three ecosystem facts should shape feature selection:

1. Flutter still documents that its built-in obfuscation only renames symbols
   and does not encrypt resources or protect against reverse engineering.
   Source: [Flutter docs](https://docs.flutter.dev/deployment/obfuscate)
2. Reverse engineering of Flutter apps is now normalized enough that OWASP has
   a dedicated technique page for it, including Blutter-based workflow.
   Source: [OWASP MASTG-TECH-0112](https://mas.owasp.org/MASTG/techniques/android/MASTG-TECH-0112/)
3. Tooling is moving toward workflow consolidation and local AI assistance.
   Blutter explicitly targets Flutter AOT binaries, and RevEngi already bundles
   Flutter analysis with a local LLM surface.
   Sources: [Blutter](https://github.com/worawit/blutter),
   [RevEngi](https://github.com/RevEngiSquad/revengi-app)

Inference from those sources:

- name-only obfuscation keeps losing value
- structural clarity is now a liability because AI can narrate recovered code
- features that waste analyst time, fragment semantic recovery, or move
  protection closer to distribution/runtime seams are more promising than just
  "more renamed things"

## Fresh Feature Candidates

## 1. Semantic Outlining And Narrative Fracture

**Short version:** split sensitive methods into multiple synthetic helpers and
state-carrying micro-steps so there is no single readable function body for a
human or LLM to summarize.

### Why it feels fresh

Most obfuscators focus on making code ugly. This feature focuses on making code
**non-coherent as a narrative unit**.

AI-assisted reverse engineering gets stronger when a method still has one
recoverable "story". If Refractor can fracture that story across synthetic
helpers, lifted closures, private carriers, and dispatcher fragments, the
analyst loses the high-level shape even when they recover names and basic
control flow.

### Kernel-level advantage

At kernel level Refractor can:

- outline selected expression clusters before final code generation
- create synthetic record/class carriers for intermediate state
- split one method into staged helpers with intentionally low semantic locality
- preserve behavior without depending on native post-processing

That is much harder for a native-only tool to do while preserving Dart-level
semantics cleanly.

### Suggested shape

- select "sensitive" procedures by annotation, config, or heuristics
- lift blocks into private synthetic helpers
- thread state through a generated carrier object or record
- optionally permute helper ownership across libraries/classes to break
  locality further
- keep generated shapes deterministic under seed

### Why this is better than plain CFF

Control flow flattening makes a function harder to step through.
Narrative fracture makes it harder to answer the bigger question:
"what does this feature actually do?"

This is more aligned with the LLM-assisted RE threat than classic switch-loop
flattening alone.

### Risks

- likely compile-time and runtime cost
- larger generated code surface
- needs careful testability and reporting
- may interact badly with inlining or tree-shaking if not anchored

### Recommendation

This is the strongest "new and fresh" Refractor-specific idea in this note.

## 2. Protection Profiles With Structural Polymorphism

**Short version:** instead of just changing names per build, change *where* and
*how* transforms apply using deterministic profile families.

### Why it feels fresh

Commercial protectors increasingly market polymorphic protection, where two
protected builds do not share the same defense topology.
Source: [DexGuard](https://www.guardsquare.com/dexguard)

For Refractor, the interesting version is not "randomize everything." It is:

- stable under a chosen profile seed
- reproducible for the operator
- structurally different across releases or channels

### Suggested shape

Introduce a top-level concept like:

- `profile: stable`
- `profile: rotating`
- `profile: canary`

And let that profile decide things like:

- which string strategy variant is used
- whether a procedure is outlined, flattened, split, or left alone
- which decoy patterns are emitted
- which integrity hooks are inserted

### Why this matters

Today an attacker can invest once and keep learning the same transform family.
Profile-based polymorphism resets that learning curve while preserving operator
control and reproducibility.

### Refractor-specific twist

Tie profile generation to:

- semantic fingerprints of the input component
- a declared policy seed
- explicit artifact reporting

So the project can say:
"This build was protected with profile `R3-canary` and these transform families
were active."

That makes polymorphism operationally usable, not just "security by chaos."

### Risks

- configuration complexity
- harder diffs between builds
- needs excellent reporting to remain supportable

### Recommendation

Very strong medium-term differentiator, especially once reporting lands.

## 3. Metadata Hygiene Pass

**Short version:** explicitly target information leaks outside ordinary symbol
rename, especially enums, build paths, library metadata, and other accidental
semantic breadcrumbs.

### Why it feels fresh

This is not flashy, but it addresses real Flutter leakage that the built-in
toolchain still leaves behind. Public issue examples include enum-name leakage
and build-path leakage in obfuscated builds.
Sources:

- [flutter/flutter#94751](https://github.com/flutter/flutter/issues/94751)
- [flutter/flutter#165111](https://github.com/flutter/flutter/issues/165111)

Most obfuscators under-invest here because it is less marketable than CFF. But
for real-world attackers, metadata breadcrumbs are incredibly valuable.

### Suggested scope

- enum-value and enum-name hardening
- library URI/path sanitization where safe
- synthetic-source naming policy for generated helpers
- optional removal or normalization of non-essential descriptive metadata
- leak scanner report that shows remaining high-value metadata

### Refractor-specific twist

Make this both:

- a transform pass where safe
- a reporting pass where transformation would be risky

That gives users immediate value even before every leak is fixable.

### Why this matters

It aligns with Refractor's current emphasis on correctness and reporting. It is
also one of the few areas where "boring" work can still feel meaningfully new,
because most tools treat metadata leakage as someone else's problem.

### Recommendation

High-value near-term research track. Less sexy than the others, but unusually
practical and well aligned with current project priorities.

## 4. Attestation-Bound Unsealing

**Short version:** let selected strings, assets, or code paths decode only when
runtime integrity or environment claims are satisfied.

### Why it feels fresh

This moves Refractor from pure static obfuscation into selective
static-plus-runtime protection, without trying to become a full RASP platform.

Commercial tooling keeps pushing app attestation and runtime integrity because
static obfuscation alone is not enough.
Source: [Guardsquare DexGuard](https://www.guardsquare.com/dexguard)

### Suggested shape

Refractor does **not** ship its own anti-root or anti-hook engine first.
Instead it defines a narrow runtime contract:

- app provides an integrity provider
- selected protected values ask that provider for an allow/deny signal
- if denied, Refractor returns a decoy, aborts decode, or delays unsealing

Examples:

- API base URL reveals only after integrity confirmation
- premium-rule tables unseal only on an attested device
- high-value strings return decoys in compromised environments

### Why this is interesting

This is materially different from ordinary string encryption:

- the attacker now needs a valid runtime condition, not just static recovery
- protection becomes composable with partner runtime tools later
- enterprise users get a bridge from code hardening to runtime policy

### Risks

- easier to misuse than pure obfuscation
- product messaging must avoid overclaiming
- requires careful failure semantics and developer ergonomics

### Recommendation

A strong long-term bet. Not the first major post-`v0.2.0` feature, but one of
the most differentiated ideas on the board.

## 5. Honey Surfaces And Forensic Canaries

**Short version:** inject fake secrets, fake protocol names, fake feature flags,
or decoy algorithm branches that are designed to mislead analysts and expose
tooling or leaks.

### Why it feels fresh

Most obfuscators try to hide truth. Very few try to plant *useful lies*.

This is especially relevant if AI-assisted reverse engineering gets good at
summarizing code. A canary-rich binary can cause the analyst, the model, or the
exfiltration pipeline to latch onto the wrong narrative.

### Possible directions

- decoy endpoints that should never be called in honest execution
- fake key material or fake feature toggles embedded with clear tracking value
- alternate helper names and metadata designed to poison simplistic summaries
- optional server-side correlation if a canary endpoint is ever touched

### Important constraint

This should not become random junk injection. To be worth it, each canary must
be:

- intentional
- attributable
- low-risk to runtime behavior
- visible in reports so operators know what was planted

### Why Refractor can own this

Kernel-level access makes it easier to insert believable decoys near real
business logic without post-compile binary patch fragility.

### Risks

- product ethics and support questions
- possible false positives if decoys are too realistic
- not all customers will want deception-based defenses

### Recommendation

Best treated as an explicitly advanced/experimental feature family.

## 6. Protected Package Distribution

**Short version:** create a supported workflow for shipping proprietary Dart or
Flutter package logic without handing out clean source.

### Why it feels fresh

This is one of the most persistent unmet needs in the ecosystem. Developers
have repeatedly asked for package/plugin obfuscation or binary distribution.
Sources:

- [flutter/flutter#98633](https://github.com/flutter/flutter/issues/98633)
- [flutter/flutter#119851](https://github.com/flutter/flutter/issues/119851)
- [dart-lang/sdk#42863](https://github.com/dart-lang/sdk/issues/42863)

Unlike generic obfuscation passes, this is a category-creating workflow
opportunity.

### Suggested shape

A future command family like:

`refractor package build`
`refractor package inspect`
`refractor package verify`

Potential outputs:

- protected `.dill`
- manifest with SDK compatibility and package API fingerprint
- optional symbol package for vendor-only support

### Why Refractor is well positioned

Because it already works at the kernel level, it can potentially protect code
*before* the final consumer app build instead of only inside an end-user app.

### Risks

- compatibility with pub and package resolution workflows
- debugability and support burden
- likely a product line of its own, not "just another pass"

### Recommendation

Potentially huge strategic differentiator. It deserves separate product
research, not just a feature doc.

## 7. WASM/Web Protection Profile

**Short version:** define transform families specifically chosen to survive
`dart2wasm` and Flutter Web pipelines.

### Why it feels fresh

Most mobile obfuscation products still center Android/iOS binaries. Refractor
could become unusually strong by saying:
"The same kernel-level protection model can also harden Dart code headed to
WASM."

That is more interesting than merely claiming "supports web".

### Suggested scope

- identify which transforms survive `dart2wasm` optimization well
- define a web-safe profile
- produce web-specific leakage reports
- avoid transform families that collapse under wasm/js optimization

### Why this matters

If the market keeps moving toward shared business logic across mobile and web,
this could become a real differentiator before commercial players care enough
to specialize there.

### Risks

- verification matrix expands quickly
- optimizer behavior may invalidate some transforms

### Recommendation

Good research lane, but after stronger mobile differentiation is in place.

## Prioritized Shortlist

If the goal is "new and fresh" without drifting into science-project territory,
the strongest shortlist is:

1. **Semantic Outlining And Narrative Fracture**
   Best mix of novelty, AI-era relevance, and kernel-level fit.
2. **Protection Profiles With Structural Polymorphism**
   Strong product differentiation once reporting and reproducibility mature.
3. **Metadata Hygiene Pass**
   Less glamorous, but highly real and unusually aligned with current
   correctness/reporting priorities.
4. **Protected Package Distribution**
   Strategic moat if the project wants a larger product ambition.
5. **Attestation-Bound Unsealing**
   High upside, but should wait until the core transformation/reporting story is
   much more mature.

## What I Would Not Lead With

These may still be useful later, but they do not feel fresh enough to headline
Refractor on their own:

- plain control flow flattening with no Dart-specific angle
- generic dead code injection
- basic asset encryption
- basic anti-debug checks without a broader runtime contract
- more rename tricks unless they materially change analyst workload

## Recommendation For Refractor

If Refractor wants to feel unlike an "average obfuscator", it should lean into
three identities:

1. **Kernel-native structural transformation**
   Do the things binary-only tools cannot do cleanly.
2. **AI-era reverse-engineering resistance**
   Focus on breaking semantic recovery, not just visual readability.
3. **Operationally trustworthy protection**
   Pair every advanced transform with reports, reproducibility controls, and
   explicit claims about what was actually verified.

In practice, that suggests this sequencing:

1. finish current reporting/confidence work
2. research and prototype `Metadata Hygiene`
3. prototype `Semantic Outlining And Narrative Fracture` on a small fixture
4. design `Protection Profiles` around deterministic reporting
5. decide whether `Protected Package Distribution` is a feature or a product
   branch

## Sources

- [Flutter obfuscation docs](https://docs.flutter.dev/deployment/obfuscate)
- [OWASP MASTG-TECH-0112: Reverse Engineering Flutter Applications](https://mas.owasp.org/MASTG/techniques/android/MASTG-TECH-0112/)
- [Blutter](https://github.com/worawit/blutter)
- [RevEngi App](https://github.com/RevEngiSquad/revengi-app)
- [Guardsquare DexGuard](https://www.guardsquare.com/dexguard)
- [flutter/flutter#94751](https://github.com/flutter/flutter/issues/94751)
- [flutter/flutter#165111](https://github.com/flutter/flutter/issues/165111)
- [flutter/flutter#98633](https://github.com/flutter/flutter/issues/98633)
- [flutter/flutter#119851](https://github.com/flutter/flutter/issues/119851)
- [dart-lang/sdk#42863](https://github.com/dart-lang/sdk/issues/42863)
