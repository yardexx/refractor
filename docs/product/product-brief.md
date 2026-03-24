# Refractor — Product Brief

> **Date:** 2026-03-13
> **Version:** 0.1.0 (early development)
> **Status:** Working prototype with rename and string encryption passes

---

## 1. Product Positioning

### What Refractor Is

Refractor is a post-compilation obfuscation tool for Dart applications. It operates on compiled Dart kernel bytecode (.dill files) — the intermediate representation that sits between Dart source code and final native compilation. By working at this level, Refractor can rewrite identifiers, encrypt strings, and apply other transformations that survive into the final binary, making reverse engineering significantly harder. It is a standalone CLI tool that slots into any Dart build pipeline: compile to kernel, obfuscate, compile to native target.

### What It Is NOT

- **Not a runtime protection tool.** It does not add anti-tampering, root detection, or runtime integrity checks.
- **Not a Flutter build plugin (yet).** It works alongside Flutter but does not integrate into `flutter build` today.
- **Not a code minifier.** The goal is obfuscation for IP protection, not reducing binary size.
- **Not a security silver bullet.** Obfuscation raises the cost of reverse engineering; it does not prevent it. It should not be used as a substitute for proper secrets management.

### Where It Sits in the Ecosystem

Dart and Flutter have no mature, purpose-built obfuscation toolchain. Flutter's `--obfuscate` flag exists but only works within Flutter builds and only renames symbols. Pure Dart applications (CLI tools, server-side, desktop) have nothing. Refractor fills this gap as an independent, composable tool that works with any Dart compilation target.

### Elevator Pitch

Refractor is the missing obfuscation toolchain for Dart. It transforms compiled kernel bytecode with pluggable passes — renaming identifiers, encrypting strings, and more — so developers can ship proprietary Dart and Flutter applications without exposing their source logic.

---

## 2. Target Users

### Persona 1: Flutter Indie Developer Shipping a Paid App

**Who they are:** Solo developer or small team (1-3 people) building a commercial Flutter app — typically a productivity tool, utility, or niche SaaS client.

**What they build:** Paid apps on the App Store and Google Play, sometimes with a freemium model. Revenue depends on the app being hard to clone.

**Why they need obfuscation:** Their competitive advantage is the app itself. A competitor with moderate skill can decompile a Flutter APK, read the Dart source logic nearly verbatim, and clone the core features. This is not hypothetical — it happens routinely on mobile app stores.

**What they use today:** Flutter's `--obfuscate` flag (renames symbols only, no string encryption, no control flow changes). Some use ProGuard/R8 on the Android side but this only touches the Java/Kotlin layer, not the Dart code.

**What frustrates them:** The `--obfuscate` flag feels like a checkbox, not real protection. String literals (API endpoints, business logic constants, error messages that reveal architecture) remain in plain text. There is no way to customize what gets obfuscated. No equivalent exists for desktop or web builds.

---

### Persona 2: Enterprise Team with Proprietary Logic

**Who they are:** A team of 5-20 developers at a company where the Dart/Flutter application contains proprietary business logic — financial calculations, recommendation algorithms, compliance rules, or trade secrets.

**What they build:** Internal tools, customer-facing apps, or SDKs distributed to partners. The code itself is IP.

**Why they need obfuscation:** Legal and compliance requirements often mandate IP protection for distributed binaries. Even internal tools distributed to field offices or partners can be reverse-engineered.

**What they use today:** Organizational policies ("don't put secrets in the client"), manual code splitting to keep sensitive logic server-side, and Flutter's `--obfuscate`. Some teams have evaluated wrapping Dart code with native modules to leverage ProGuard/R8 or iXGuard, which is expensive and fragile.

**What frustrates them:** No enterprise-grade solution exists in the Dart ecosystem. The workaround of moving logic server-side introduces latency, offline limitations, and architectural complexity. They want something like ProGuard but for Dart — configurable, auditable, and integrated into CI/CD.

---

### Persona 3: Dart Backend Developer with Proprietary Algorithms

**Who they are:** Developer shipping a Dart CLI tool, server-side application, or compiled utility that contains proprietary algorithms or logic. Often in fintech, data processing, or developer tooling.

**What they build:** `dart compile exe` binaries distributed to customers or deployed on shared infrastructure.

**Why they need obfuscation:** Compiled Dart executables retain symbol names and string literals. Running `strings` on a Dart exe reveals function names, class names, error messages, and often the entire architecture of the application. For proprietary algorithms, this is unacceptable.

**What they use today:** Nothing. There is literally no obfuscation tool for pure Dart applications. Flutter's `--obfuscate` does not apply. Some developers write a post-processing script to strip symbols, but this is brittle and loses debug information.

**What frustrates them:** They chose Dart for its performance and developer experience, but the lack of binary protection is a gap they did not anticipate. In other ecosystems (Java, .NET, JavaScript), obfuscation tooling is mature and readily available.

---

### Persona 4: Flutter Agency Building White-Label Apps

**Who they are:** A development agency building apps for multiple clients using a shared codebase or framework. They customize and rebrand the same core for different clients.

**What they build:** White-label apps where the agency's framework is the product. Clients get a customized build; the core framework is the agency's IP.

**Why they need obfuscation:** Each client receives a binary that contains the agency's proprietary framework. Without obfuscation, any client (or their developer) can decompile the app and extract the shared framework, undermining the agency's business model.

**What they use today:** Contractual protections (NDAs, license agreements) and Flutter's `--obfuscate`. Some agencies split their framework into a compiled Dart package, but the Dart package format does not support distributing pre-compiled code with obfuscation.

**What frustrates them:** They need per-client obfuscation with stable symbol maps (so crash reports are still debuggable). No existing tool supports this workflow.

---

### Persona 5: Security-Conscious Developer (API Keys and Secrets)

**Who they are:** Any developer who has hardcoded API keys, endpoint URLs, or configuration secrets in their Dart code — knowingly or unknowingly.

**What they build:** Anything. This persona cuts across all others.

**Why they need obfuscation:** String literals in Dart binaries are trivially extractable. API keys, Firebase config, internal URLs, and encryption keys are all visible with `strings` or a hex editor. String encryption makes casual extraction significantly harder.

**What they use today:** Environment variables at build time, `.env` files, server-side config fetching, or manual encryption wrappers. These are inconsistently applied and often incomplete.

**What frustrates them:** The "right" solution (never put secrets in the client) is architecturally expensive and sometimes impossible (offline-first apps, SDK distributions, embedded devices). They want a pragmatic middle ground.

**Important caveat:** Refractor's string encryption is a defense-in-depth measure, not a secrets vault. XOR encryption with a key embedded in the binary is obfuscation, not security. It stops casual extraction, not determined reverse engineering. This persona should still pursue proper secrets management where possible.

---

## 3. Competitive Landscape

### Flutter's Built-in `--obfuscate`

**What it does:**
- Renames Dart symbols in Flutter release builds
- Generates a symbol map for crash report deobfuscation
- Zero configuration — it is a single flag

**What it does not do:**
- No string encryption
- No control flow obfuscation
- No customization (cannot exclude specific classes or choose naming strategies)
- Does not work for pure Dart (non-Flutter) applications
- Does not work for kernel or JIT targets
- No programmatic API — tied to the Flutter build system

**Verdict:** A reasonable default for Flutter apps that need basic symbol renaming. Insufficient for anyone with real IP protection needs.

### ProGuard / R8 (Android Ecosystem)

**What it is:** The gold standard for JVM/Android obfuscation. ProGuard (now largely superseded by R8) provides identifier renaming, string encryption, control flow obfuscation, class merging, dead code removal, and optimization — all in one tool.

**Why it matters:** ProGuard set the expectations for what an obfuscation tool should do. Developers coming from Android/Java expect this level of sophistication. Refractor's pass architecture maps directly to ProGuard's pipeline model.

**The gap:** ProGuard/R8 does not touch Dart code in a Flutter app. It only processes the Java/Kotlin wrapper layer. The Dart bytecode (which contains the actual application logic) passes through untouched.

### Commercial Solutions (DexGuard, iXGuard)

**What they are:** Enterprise-grade obfuscation tools from Guardsquare. DexGuard extends ProGuard for Android; iXGuard handles iOS. Pricing is enterprise-only (typically $10K-$50K+/year).

**Relevance:** These tools protect the native layer but, like R8, do not touch Dart code. Some Flutter enterprise teams use DexGuard/iXGuard for the native wrapper and accept that the Dart layer is unprotected.

**Opportunity:** There is no Dart-native equivalent at any price point. Refractor could be the first.

### JavaScript Obfuscators (Table Stakes Reference)

The JavaScript ecosystem has mature obfuscation tools (javascript-obfuscator, Terser, Google Closure Compiler) that define "table stakes" features:

- **Identifier renaming** (mangling) — table stakes
- **String encryption/encoding** — table stakes
- **Dead code injection** — common but debatable value
- **Control flow flattening** — differentiator (transforms if/else into switch-in-loop patterns)
- **Self-defending code** — advanced (crashes if formatted/beautified)
- **Domain locking** — advanced (code only runs on specified domains)
- **Debug protection** — advanced (detects debugger attachment)

**Lesson from JS:** String encryption and identifier renaming are the minimum viable feature set. Control flow obfuscation is what separates serious tools from toys. Self-defending and anti-debug features are premium but niche.

### Why Nothing Exists for Dart

Several factors explain the gap:

1. **Small market perception.** Dart is still seen as "Flutter's language." The broader Dart ecosystem (server-side, CLI, desktop) is growing but not yet large enough to attract commercial tool vendors.
2. **Kernel format is undocumented.** The .dill format is an internal SDK implementation detail. It changes between SDK versions with no stability guarantees. Building on it requires vendoring SDK code and accepting maintenance burden.
3. **Flutter's `--obfuscate` is "good enough" for most.** The majority of Flutter developers either do not need obfuscation or are satisfied with basic symbol renaming.
4. **The Dart team may address this eventually.** There is latent risk that the Dart SDK team adds more comprehensive obfuscation, though this seems unlikely given their priorities.

---

## 4. Core Differentiators

### 1. Kernel-Level Transformation

Refractor operates on the compiled kernel AST, not source code. This means:
- It sees the code exactly as the compiler does — no parsing ambiguities, no macro expansion issues
- Transformations are guaranteed to produce valid kernel bytecode (when implemented correctly)
- It works regardless of how the source was written — codegen, macros, FFI, all become kernel nodes

Source-to-source obfuscation (common in JavaScript) is fragile because it must handle the full language surface. Kernel-level transformation is narrower and more reliable.

### 2. Pass-Based Architecture

The `Pass` interface and sequential `PassRunner` make it straightforward to add
new obfuscation techniques without rewriting the pipeline. Each pass operates
on a kernel `Component` and returns explicit execution data via `PassResult`.
Pass reports and optional artifacts are collected for downstream consumers
(e.g., symbol maps and future reporters).

This is not just an internal implementation detail — it is a product differentiator. It means:
- Users can enable/disable individual passes in their config
- New passes can be developed and tested independently
- Third-party passes could be loaded as plugins (future)

### 3. Correctness Guarantees for Rename

The rename pass is architecturally sophisticated. The override family system (Union-Find + class hierarchy index + external member filtering) ensures that:
- Overridden methods across inheritance chains get the same obfuscated name
- SDK and third-party members are never renamed (preserving interop)
- Private members are scoped correctly per library
- `@pragma` annotations are respected for opt-out

Getting this wrong produces silent runtime crashes. Refractor's decomposed architecture (collector -> analyzer -> allocator -> transformer) makes each step testable and verifiable. This is a meaningful technical moat.

### 4. Pure Engine, No I/O Dependencies

The engine layer has zero `dart:io` imports. All I/O is abstracted behind `Compiler` and `KernelIO` interfaces. This means the engine can be:
- Embedded in build systems (build_runner, Flutter build hooks)
- Used in IDE extensions
- Tested without filesystem access
- Run in environments where `dart:io` is restricted

This is unusual for CLI tools and creates real optionality for future integration paths.

### 5. Open Source

There is no competing open-source Dart obfuscation tool. Being first and open-source creates:
- Community contributions and bug reports across diverse codebases
- Trust (users can audit exactly what the tool does to their code)
- Adoption in CI/CD pipelines where commercial tools face procurement friction

---

## 5. Feature Roadmap Tiers

### Tier 1 — Table Stakes

*What you need to be taken seriously as an obfuscation tool.*

**Complete rename coverage**
The rename transformer must handle every kernel AST node type that references a `Name`. The architecture review flags that several node types (`DynamicInvocation`, `FunctionInvocation`, `EqualsCall`, `RecordIndexGet`, `TypedefTearOff`) are not yet covered. A single missed node type means stale names at runtime, which means crashes. Users will not tolerate this.

*Why it matters:* If the tool breaks real programs, nothing else matters.

**End-to-end integration tests**
Currently all tests use synthetic kernel ASTs. At least a basic suite that compiles real Dart programs, obfuscates them, and verifies they still run correctly is essential. Without this, every release is a gamble.

*Why it matters:* Unit tests passing while the tool produces broken binaries is the nightmare scenario. One public incident of "Refractor broke my app" would be devastating for adoption.

**Source text stripping**
The demo revealed that .dill files embed original source text as debug metadata. Even with perfect identifier renaming, running `strings` on the binary reveals the original code. This metadata must be stripped or obfuscated.

*Why it matters:* This undermines every other protection. A user who inspects their "obfuscated" binary and finds the original source text will lose trust immediately.

**Stable symbol map output**
The symbol map (obfuscated name -> original name) must be reliable, well-documented, and integrate with crash reporting workflows. Users need to be able to deobfuscate stack traces.

*Why it matters:* Obfuscation without debuggability is a non-starter for production use.

**Documentation and examples**
A getting-started guide, configuration reference, and at least one worked example (obfuscate a sample app, inspect the before/after, deobfuscate a stack trace).

*Why it matters:* Open-source tools without documentation do not get adopted. The `inspect` command is a huge asset here — it can power interactive demos.

---

### Tier 2 — Differentiators

*What makes Refractor meaningfully better than `--obfuscate`.*

**Control flow flattening pass**
Transform structured control flow (if/else, switch, loops) into a state machine pattern (switch-in-loop). This is the single most impactful obfuscation technique after renaming and string encryption. It makes decompiled code nearly unreadable even if all names are recovered.

*Why it matters:* Renaming and string encryption are speed bumps. Control flow flattening is a wall. This is what separates "basic obfuscation" from "serious obfuscation."

**Dry-run / diff mode**
A `--dry-run` flag that reports what would be renamed/encrypted without modifying anything. Ideally, a before/after diff view using the `inspect` command.

*Why it matters:* Users need to trust the tool before running it on production code. A dry run lets them verify scope, catch unexpected renames, and build confidence incrementally.

**Selective obfuscation (include/exclude patterns)**
Fine-grained control over what gets obfuscated: by library, by class, by annotation, by glob pattern.

*Why it matters:* Real-world apps have code that must not be obfuscated — serialization classes (JSON keys become obfuscated), reflection-dependent code, public API surfaces.

**Incremental symbol maps**
Stable obfuscated names across builds when the source does not change. This means caching the symbol map and reusing it.

*Why it matters:* Crash reports from version 1.2.3 need to be deobfuscated with the symbol map from that exact build. Enterprise users will require this.

**Flutter build integration**
Either a `build_runner` builder or a Flutter build hook that makes obfuscation a single line in `pubspec.yaml`.

*Why it matters:* Asking Flutter developers to run a separate CLI tool is friction. The closer Refractor gets to "add a dependency and it just works," the wider the adoption.

---

### Tier 3 — Moat

*What makes Refractor hard to replace once adopted.*

**Plugin system for third-party passes**
Allow developers to write custom obfuscation passes loaded from pub packages.
The current pass model supports this direction architecturally, but the missing
piece is still a loading/registration mechanism.

*Why it matters:* A plugin ecosystem creates network effects. Once a community builds passes for domain-specific obfuscation, Refractor becomes a platform, not just a tool.

**AI-powered name generation**
The architecture already has a pluggable `NameGenerator`. An AI-backed generator that produces plausible-but-misleading names (e.g., renaming a pricing algorithm's methods to look like logging utilities) would be a unique differentiator.

*Why it matters:* Traditional obfuscation produces obviously obfuscated names (`a`, `b`, `_$0`). Misleading names create a qualitatively different challenge — the reverse engineer cannot trust any name, even ones that look natural.

**Binary watermarking**
Inject unique, invisible markers into each build that identify the licensee. If a decompiled version appears in the wild, the watermark traces it back to the source.

*Why it matters:* Turns obfuscation from defense into deterrence. High value for agencies and enterprise teams.

**Obfuscation strength analysis**
A scoring system that analyzes the obfuscated binary and reports how effective each pass was — what percentage of symbols were renamed, how many strings were encrypted, control flow complexity metrics.

*Why it matters:* Users cannot evaluate obfuscation quality without this. Makes for excellent marketing content.

**Multi-language coordination**
For Flutter apps, coordinate Dart obfuscation with ProGuard/R8 (Android) and LLVM obfuscation (iOS) to ensure consistent protection across all layers.

*Why it matters:* The weakest layer determines overall protection. Orchestrating protection across Dart + native layers would be genuinely unique.

---

## 6. Go-to-Market Ideas

### Getting Initial Users

**"Decompile your Flutter app" content series.** Write a blog post or create a video showing exactly how easy it is to decompile a Flutter APK and read the Dart source. Show the before (plain text class names, API URLs, business logic) and after (obfuscated). This is the single most effective way to create urgency.

**Dart/Flutter security audit tool.** Before pushing Refractor as a solution, offer the `inspect` command as a standalone utility. "See what is in your .dill file." Let developers discover the problem themselves.

**GitHub Actions integration.** Publish a GitHub Action that adds obfuscation to any Dart/Flutter CI pipeline. Lower the activation energy to near zero.

**pub.dev presence.** Having a pub.dev listing gives visibility in the ecosystem where developers already search.

### Content and Demos

- **Interactive playground:** A web app where users paste Dart code, see the kernel representation, and see the obfuscated output
- **"What's in your binary?" blog post:** Step-by-step guide to running `strings` on a compiled Dart exe
- **Comparison post:** "Flutter --obfuscate vs. Refractor: what actually changes in your binary"
- **Architecture deep-dive:** "How we handle inheritance in Dart obfuscation"

### Community Strategy

- Open issues labeled "good first issue" for new passes or configuration options
- Maintain a public roadmap (GitHub Projects or similar)
- Respond fast to bug reports — for a security-adjacent tool, trust is everything
- Accept pass contributions via the plugin system rather than merging everything into core
- Consider a Discord or GitHub Discussions for support

### Conference and Meetup Opportunities

- **FlutterCon / Flutter Vikings / Flutteristas:** "Protecting Your Flutter App's Source Code"
- **Dart/Flutter meetups:** Live demo of decompiling an app and then obfuscating it
- **OWASP / AppSec events:** Position Refractor in the mobile security context

---

## 7. Risks and Honest Assessment

### What Could Kill This Project

**Dart SDK team adds comprehensive obfuscation.** If the Dart team builds ProGuard-level obfuscation into the SDK, Refractor's reason to exist narrows considerably. Mitigation: move fast on Tier 2 and Tier 3 features that go beyond what a platform team would build.

**Kernel format instability.** The .dill format is an internal SDK implementation detail. Every Dart SDK release could break Refractor. Mitigation: automated CI against Dart SDK beta/dev channels, tight version pinning, community testers.

**A broken release that corrupts user binaries.** The architecture review identifies incomplete AST node coverage. For a security tool, trust is the product. Mitigation: end-to-end tests are the single highest priority item.

**Solo maintainer burnout.** Keep the codebase lean, the test suite strong, and the maintenance burden low.

### Hardest Technical Challenges

1. **Keeping up with Dart SDK kernel changes.** Ongoing tax on every release.
2. **Control flow flattening that survives VM optimizations.** Requires deep understanding of the VM's optimization passes.
3. **Correctness across the full AST node surface.** Completeness problem requiring systematic auditing.
4. **Flutter integration without forking Flutter's build system.** Requires either build hooks (experimental) or a `build_runner` builder.

### Is the Market Big Enough?

**Honest answer: probably not for a venture-backed business. Probably yes for a sustainable open-source project.**

The realistic initial market is:
- Indie developers with paid apps (hundreds, maybe low thousands)
- Enterprise Flutter teams (dozens to low hundreds of companies)
- Dart backend developers (small but growing)
- Agencies with white-label frameworks (dozens)

This is enough to sustain an open-source project. It is not enough to build a company around.

**The upside case:** If Dart's server-side story gains traction, the market for Dart binary protection grows significantly.

### Open Source Sustainability

Options, in order of realism:

1. **Maintainer uses it professionally.** Most sustainable model.
2. **GitHub Sponsors / Open Collective.** Unlikely to fund significant development.
3. **Dual licensing or premium passes.** Open-source core, paid advanced passes. Viable but adds complexity.
4. **Consulting / support contracts.** Small but real revenue from enterprise adopters.
5. **Acquisition by a security company.** Unlikely but non-zero.

**Honest recommendation:** Build this because you need it or because you find it technically interesting. Keep the codebase lean, the test suite strong, and the maintenance burden low.

---

## Summary of Top 5 Priorities

1. **Complete AST node coverage in the rename transformer.** Without this, the tool is not safe for real programs.
2. **Add end-to-end integration tests.** Without this, you cannot know if it is safe.
3. **Strip source text from .dill binaries.** The demo revealed this undermines all other protections.
4. **Write a "decompile your Flutter app" blog post.** Highest-leverage marketing activity, costs nothing.
5. **Build the control flow flattening pass.** The feature that makes Refractor worth using over `--obfuscate`.
