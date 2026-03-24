# Architecture Review: Refractor

> **Date:** 2026-03-12
> **Branch:** `feature/tier1-rename-coverage`
> **Reviewers:** Software Architect, Senior Software Engineer, Product Strategist, DX Specialist

---

## 1. Project Understanding

**Refractor** is a Dart kernel (.dill) obfuscation tool. It operates on compiled Dart intermediate representation (the kernel binary format) to transform identifiers and strings before final compilation to native targets.

### Components

| Layer | Location | Responsibility |
|-------|----------|---------------|
| **CLI** | `lib/src/cli/` | Command-line interface: `build`, `init`, `inspect` commands |
| **Config** | `lib/src/config/` | YAML-based configuration parsing, pass config model hierarchy |
| **Engine** | `lib/src/engine/` | Core obfuscation pipeline: compiler abstraction, kernel I/O, pass runner, and pass implementations |
| **Utils** | `lib/src/utils/` | Shared utilities: `DisjointSet<T>`, process runner, rename helpers |
| **Exceptions** | `lib/src/exceptions/` | Sealed exception hierarchy with domain-specific exit codes |
| **Packages** | `packages/` | Workspace sub-packages: `kernel_model` (dill inspection), vendored `third_party/kernel` (Dart SDK kernel library) |

### Interaction Flow

```
CLI (BuildCommand)
  -> ConfigManager.loadConfig()     -> RefractorConfig
  -> RefractorEngine.run()
      -> Compiler.compileToKernel() -> .dill file
      -> KernelIO.load()            -> Component (AST)
      -> PassRunner.run()           -> runs [RenamePass, StringEncryptPass] sequentially
          -> each Pass mutates the Component in place
      -> KernelIO.write()           -> obfuscated .dill
      -> Compiler.compileToTarget() -> exe/aot/jit output
  -> SymbolTableIo.writeToPath()    -> JSON symbol map
```

### Core Functionality

The **rename pass** is the most sophisticated piece. It:

1. **Collects** all renamable declarations via `DeclarationCollector` (single AST walk)
2. Builds a `ClassRelationIndex` (transitive super/subtypes)
3. Groups instance members into **override families** using `OverrideFamilyAnalyzer` + `DisjointSet` (Union-Find) — ensuring overridden methods across a hierarchy get the same obfuscated name
4. Generates names via pluggable `NameGenerator` (sequential or seeded-shuffled)
5. Allocates names via `NameAllocator` (handles privacy prefixes, library scoping)
6. Applies mutations via `RenameTransformer` (rewrites declarations + all call sites)

The **string encrypt pass** XOR-encodes string literals and injects a runtime decoder procedure directly into the kernel AST.

---

## 2. Product Summary

**What it is:** A post-compilation obfuscation tool for Dart applications. It sits between `dart compile kernel` and final target compilation (exe/aot/jit), transforming the kernel AST to obscure identifiers and string literals.

**What problem it solves:** Dart's native compilation produces binaries that retain human-readable symbol names and string constants. Refractor strips this information to protect intellectual property and raise the bar for reverse engineering.

---

## 3. Value Proposition

| Dimension | Detail |
|-----------|--------|
| **Target user** | Dart/Flutter developers shipping proprietary applications (desktop, server-side, CLI tools) who need IP protection beyond what `dart compile` offers natively |
| **Core benefit** | Automated, reproducible obfuscation integrated into the Dart build pipeline — no manual binary patching, no third-party runtime dependencies |
| **Why this over alternatives** | Dart has no first-party obfuscation tool. Flutter's `--obfuscate` flag only works for Flutter apps and only renames. Refractor offers (a) broader scope (string encryption + rename), (b) works for pure Dart, (c) pluggable pass architecture, (d) symbol map output for stack trace deobfuscation, (e) respects class hierarchies and SDK boundaries to maintain correctness |

**Alternative interpretation:** This could also serve as a research/educational tool for understanding the Dart kernel format and AST transformation capabilities — the `inspect` command and vendored kernel library support this use case.

---

## 4. Architecture Overview

**Architectural style:** Layered, CLI-oriented, pass-based pipeline.

Three strict layers with unidirectional dependency: `CLI -> Config -> Engine`. The engine layer is intentionally free of `dart:io` — all I/O is abstracted behind `Compiler` and `KernelIO` interfaces, injected by the CLI layer.

### Module Responsibilities

- **CLI:** Parses arguments, orchestrates workspace setup, wires concrete I/O implementations into the engine
- **Config:** Deserializes YAML -> typed `RefractorConfig`
- **Engine:** Pure transformation logic. The `RefractorEngine` orchestrates the compile->obfuscate->compile pipeline. `PassRunner` executes passes sequentially. Each pass (rename, string_encrypt) owns its own sub-module with collector/analyzer/transformer components.

### Data Flow

The kernel `Component` (a mutable AST tree) flows through passes sequentially. Each pass mutates it in place. Side results (e.g., `RenameMapping`) are collected into `PassResults` for upstream consumers.

### Design Patterns in Use

- **Visitor/Transformer pattern:** `RecursiveVisitor` (collection), `Transformer` (mutation) from the kernel library
- **Strategy pattern:** `NameGenerator` abstraction with sequential/shuffled implementations
- **Union-Find:** `DisjointSet<T>` for grouping override families
- **Sealed execution model:** `PassResult`, `PassSucceeded`, `PassFailed`
- **Sealed class hierarchies:** `PassConfig`, `RefractorException`, `PassResult`

---

## 5. Architecture Strengths

### Excellent Separation of Concerns

The engine layer has zero `dart:io` imports. `Compiler` and `KernelIO` abstractions allow the engine to be tested with mock implementations or reused in non-CLI contexts (e.g., a build system plugin, IDE extension).

### Well-Designed Pass Pipeline

The `Pass` -> `PassRunner` -> `PassResults` design is clean and extensible.
Adding a new pass requires implementing one interface, and pass execution
outcomes are now first-class through `PassResult`, `PassReport`, and optional
artifacts.

### Correctness-Focused Rename Architecture

The override family system (Union-Find + ClassRelationIndex + external member filtering) is the most architecturally significant piece. It correctly handles:

- Override chains across inheritance hierarchies
- External supertype member preservation (SDK/third-party)
- Private member library scoping
- `@pragma` annotation opt-out

This is non-trivial to get right and the decomposition into `DeclarationCollector -> ClassRelationIndex -> OverrideFamilyAnalyzer -> NameAllocator -> RenameTransformer` makes each step testable in isolation.

### Strong Testing Strategy

~30+ rename pass tests cover edge cases (SDK overrides, TFA compatibility, call-site consistency, round-trip serialization). Tests operate on synthetic kernel AST nodes — fast, deterministic, no filesystem needed. The `kernel_helpers.dart` test factory is well-designed.

### Clean Error Model

The sealed `RefractorException` hierarchy with domain-specific exit codes is
production-grade. Inside the pass pipeline, failures are represented explicitly
via `PassFailed` records instead of being hidden behind a generic `Result<T>`
wrapper.

### Good Use of Dart Language Features

Sealed classes, pattern matching (`switch` on `Result`), `part`/`part of` for config models, `json_serializable` code generation — the codebase leverages modern Dart idioms effectively.

---

## 6. Architecture Weaknesses

### Config-to-Engine Coupling

Pass parsing and pass construction are still coupled across the config and
engine boundary. Adding a new pass requires updating
`PassConfigListConverter` and `PipelineBuilder`, so the extension seam is not
yet centralized.

### In-Place Mutation Model

Passes mutate the kernel `Component` in place. This means:

- No rollback on partial failure (if pass 2 fails, pass 1's mutations persist)
- No before/after comparison without serialization
- Pass ordering is implicit — a pass can silently depend on another pass's mutations

### PassResults Uses Stringly-Typed Lookup

`results.get<RenameMapping>('rename')` relies on matching the pass name string. A typo or name change silently returns `null`. The `Map<String, Object?>` loses type safety.

### Pass Construction Has No Named Registry

`PipelineBuilder` uses a manual switch over built-in `PassConfig` types. This
is acceptable at the current size, but it means the answer to "where do I add a
new pass?" is still spread across multiple files instead of one obvious seam.

### PassConfigListConverter Contains a Manual Switch

Adding a new pass requires updating both the converter's `switch` and
`PipelineBuilder`. There's no registry or discovery mechanism yet.

### StringEncryptPass._injectHelper Is Fragile

The helper injection manually constructs kernel AST nodes by resolving `dart:core` classes by name string (`'int'`, `'String'`, etc.). This is brittle if the SDK changes internal representations.

---

## 7. Architectural Risks

### 1. Kernel AST Compatibility

**Risk:** The vendored `third_party/kernel` package is a snapshot of the Dart SDK's kernel library. Dart SDK upgrades may introduce AST changes (new node types, changed semantics) that break the transformer.

**Impact:** High. A broken transformer produces corrupt binaries silently.

**Mitigation needed:** Version pinning strategy, integration tests against real Dart projects, round-trip serialization verification.

### 2. Incomplete Call-Site Coverage in RenameTransformer

**Risk:** The transformer handles `InstanceGet`, `InstanceSet`, `InstanceInvocation`, `SuperPropertyGet/Set`, `SuperMethodInvocation`, `ConstructorInvocation`, `StaticInvocation` — but Dart's kernel has additional node types (`DynamicInvocation`, `FunctionInvocation`, `EqualsCall`, `RecordIndexGet`, `TypedefTearOff`, etc.). Unhandled call sites would retain stale names.

**Impact:** High. Runtime crashes or subtle bugs in obfuscated binaries.

**Mitigation needed:** Audit against the kernel visitor's full node set; add integration tests with real-world codebases.

### 3. Single-Threaded Sequential Pass Execution

**Risk:** Not a correctness risk, but a performance risk. For large codebases, the rename pass does O(n^2) pairwise class comparisons in `OverrideFamilyAnalyzer.analyze()`.

**Impact:** Medium. Build times could grow significantly with large class hierarchies.

### 4. No Integration/End-to-End Test Suite

**Risk:** All tests use synthetic kernel ASTs. No test compiles a real Dart program, obfuscates it, and verifies runtime behavior.

**Impact:** High. The unit tests can all pass while the tool produces broken binaries for real programs.

### 5. Private Member Scoping Assumptions

**Risk:** `NameAllocator` uses `member.enclosingLibrary` for private member library scoping. If a member is inherited from another library via mixin, the enclosing library may not match the privacy scope of the name.

**Impact:** Medium. Could produce name collisions in specific mixin scenarios.

---

## 8. Recommended Improvements

### 1. Introduce a Pass Registry

Replace the manual switch statements in `PassConfigListConverter` and
`PipelineBuilder` with a small registry pattern:

```dart
abstract class PassFactory<C extends PassConfig, P extends Pass> {
  String get name;
  C parseConfig(Map<String, dynamic> json);
  P create(C config);
}
```

**Tradeoff:** Adds indirection. Worth it when you have 3+ passes or want plugin support.

### 2. Keep SymbolTable IO at the CLI Boundary

This is already fixed on the current branch through
`lib/src/cli/symbol_table_io.dart`. Keep future symbol-format work following
that same boundary.

**Tradeoff:** Minimal — the boundary is already clearer now.

### 3. Add End-to-End Tests

Create a `test/e2e/` directory with small Dart programs that get compiled -> obfuscated -> executed. Verify the output matches expected behavior.

**Tradeoff:** Slower tests, requires Dart SDK in CI. Essential for confidence.

### 4. Add an AST Node Coverage Audit for RenameTransformer

Systematically enumerate all `Expression`/`Statement` types that reference `Name` objects and verify the transformer handles them. Could be a compile-time check or a test.

**Tradeoff:** One-time effort with high correctness payoff.

### 5. Decouple Config from Engine Pass Constructors

Keep `RefractorConfig` as pure parsed data and let a separate pass-construction
layer own instantiation. The current code is already closer to this through
`PipelineBuilder`, but the seam could be made more explicit.

**Tradeoff:** More indirection. Worth it if the config layer needs to be reusable across different engine versions.

### 6. Consider Immutable Pipeline Model

Instead of mutating `Component` in place, consider cloning per-pass or using a write-ahead log pattern for rollback capability. At minimum, serialize the component before the first pass so failures can recover.

**Tradeoff:** Memory/performance cost. May not be justified until the tool handles large projects.

---

## 9. Developer Experience Review

### Repository Clarity: Good

The directory structure is intuitive. `lib/src/{cli,config,engine,utils,exceptions}` maps cleanly to responsibilities. The `packages/` workspace for vendored dependencies is well-organized.

### Onboarding Difficulty: Medium

- The project's domain (kernel AST transformation) is inherently complex
- The docs tree exists and is useful, but some files still need regular
  refreshes to stay aligned with current code
- The `CLAUDE.md` and memory files provide excellent context for AI-assisted development but don't substitute for human onboarding docs
- The `init` command with its template YAML is good DX for end users
- The `inspect` command is an excellent debugging/learning tool

### Testability: Good

- Engine layer's IO-free design makes unit testing straightforward
- `kernel_helpers.dart` provides clean test factories
- Test structure mirrors source layout
- Tests are focused and well-named
- **Gap:** no integration tests, no mocking of `DartCompiler`/`FileKernelIO` in engine tests

### Maintainability: Good

- Consistent code style (very_good_analysis)
- Small, focused files (most under 100 lines)
- Clear naming conventions
- Sealed types enforce exhaustive handling
- The rename pass decomposition (collector -> analyzer -> allocator -> transformer) makes changes surgical

### CI/CD: Good

- Format check, analysis, tests, coverage, and pana scoring in CI
- Coverage uploaded to Codecov
- Runs on push to main, release/*, and dev/* branches

---

## 10. Architecture Roadmap

### Phase 1 — Immediate (stability and correctness)

1. **Refresh architecture docs to current code** — avoids contributors learning
   removed pass-system shapes
2. **Add E2E test with a real Dart program** — even one smoke test that compiles->obfuscates->runs a hello-world program would catch fundamental regressions
3. **Audit `RenameTransformer` for unhandled AST node types** — compare against `kernel/visitor.dart`'s full list of `visit*` methods that reference `Name`
4. **Fix the 3 failing `init_command_test` cases** and the unused import analysis warning

### Phase 2 — Medium-term (extensibility)

1. **Introduce a Pass registry/factory** — decouple config parsing from pass construction
2. **Add a `ControlFlowFlattenPass`** or **`DeadCodeInsertionPass`** — the architecture is ready for it; this validates the extensibility story
3. **Add before/after binary diff tooling** — extend `inspect` to compare two .dill files, useful for validating obfuscation coverage
4. **Add a `--dry-run` mode** that reports what would be renamed without mutating

### Phase 3 — Long-term (ecosystem and scale)

1. **Plugin system** — allow third-party passes loaded from packages
2. **Incremental obfuscation** — cache symbol maps between builds for stable obfuscated names across versions (important for crash reporting)
3. **Flutter integration** — a `build_runner` builder or Flutter build hook that integrates Refractor into `flutter build`
4. **Performance optimization** — the O(n^2) override family analysis could be replaced with a hash-based approach using canonical hierarchy signatures; parallelization of independent passes
5. **AI-powered name generation** — the `NameGenerator` abstraction already anticipates this (the comment mentions "AI generator — sends scope to AI for plausible names"). This would generate realistic-looking but misleading names to confuse reverse engineers

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `lib/src/engine/engine.dart` | Main orchestrator (`RefractorEngine`) |
| `lib/src/engine/pass/pass.dart` | `Pass` base interface |
| `lib/src/engine/pass_runner.dart` | Sequential pass execution |
| `lib/src/engine/passes/rename/rename_pass.dart` | Rename pass orchestrator |
| `lib/src/engine/passes/rename/rename_transformer.dart` | AST mutation for renames |
| `lib/src/engine/passes/rename/declaration_collector.dart` | AST walk for declarations |
| `lib/src/engine/passes/rename/override_family/override_family_analyzer.dart` | Union-Find family grouping |
| `lib/src/engine/passes/rename/override_family/class_relation_index.dart` | Class hierarchy index |
| `lib/src/engine/passes/rename/name_allocator.dart` | Name assignment with privacy |
| `lib/src/engine/passes/rename/name_generator/name_generator.dart` | Pluggable name strategy |
| `lib/src/engine/passes/string_encrypt/string_encrypt_pass.dart` | XOR string encryption |
| `lib/src/engine/passes/string_encrypt/string_encrypt_transformer.dart` | String literal replacement |
| `lib/src/engine/compiler/compiler.dart` | Abstract compiler + `Target` enum |
| `lib/src/engine/kernel/kernel_io.dart` | Abstract kernel I/O |
| `lib/src/engine/pipeline_builder.dart` | Built-in pass construction |
| `lib/src/config/model/refractor_config.dart` | Config model |
| `lib/src/config/config_manager.dart` | YAML config loader |
| `lib/src/cli/command_runner.dart` | CLI entry point |
| `lib/src/cli/commands/build_command.dart` | Build pipeline command |
| `lib/src/utils/disjoint_set.dart` | Union-Find data structure |
| `lib/src/exceptions/refractor_exception.dart` | Sealed exception hierarchy |
| `test/helpers/kernel_helpers.dart` | Test factories for kernel AST |
