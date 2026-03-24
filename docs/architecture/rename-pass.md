# RenamePass Architecture

## Role

`RenamePass` is a dumb orchestrator. It wires together three components based on
its options, runs them in sequence, and returns a `PassResult`. On success, the
result carries a `RenameArtifact` containing the obfuscation map.

```dart
class RenamePass extends Pass {
  RenamePass({required this.options});
  final RenamePassOptions options;

  @override
  Future<PassResult> run(
    Component component,
    ObfuscationTarget target,
  ) async {
    final scope = RenameCollector().collect(component, target, options);
    final names = await _generator.generate(scope);
    final mapping = NameAllocator().allocate(scope, names);
    RenameApplier(target).apply(component, mapping);
    return PassSucceeded(
      artifact: RenameArtifact(mapping: mapping),
      report: PassReport(passName: name),
    );
  }
}
```

No logic lives here — just construction and sequencing.

## Three Phases

### 1. Collect — `RenameCollector` → `RenameScope`

`RenameCollector` is itself a small orchestrator. It coordinates three single-purpose components, each doing one thing:

```dart
class RenameCollector {
  RenameScope collect(
    Component component,
    ObfuscationTarget target,
    RenamePassOptions options,
  ) {
    // 1. Walk AST, pick up raw declarations.
    final declarations = DeclarationCollector(target, options)
        .collect(component);

    // 2. Build class hierarchy index.
    final hierarchy = ClassRelationIndex.build(
        declarations.classes.map((c) => c.node));

    // 3. Group instance members into override families.
    final families = OverrideFamilyAnalyzer()
        .analyze(declarations.classes, hierarchy);

    return RenameScope(
      classes: declarations.classes,
      topLevelMembers: declarations.topLevelMembers,
      variables: declarations.variables,
      overrideFamilies: families,
    );
  }
}
```

Three components, each testable in isolation:

- **`DeclarationCollector`** — single AST walk. Visits libraries, classes, members, variables. Filters by `ObfuscationTarget`, `@pragma`, `preserveMain`. Outputs raw `ClassScope` list + top-level members + variables. Knows nothing about families or hierarchy.

- **`ClassRelationIndex`** — takes a list of classes, builds hierarchy index. Pure data structure. Answers `areRelated(a, b)` and `shareDeclaringSupertypeForName(a, b, name)`.

- **`OverrideFamilyAnalyzer`** — takes `ClassScope` list + hierarchy, groups instance members into families using Union-Find. Returns `OverrideFamilies`. No AST walking, no filtering.

**What gets filtered out (by `DeclarationCollector`):**

- SDK and third-party libraries (via `ObfuscationTarget`)
- `@pragma`-annotated declarations
- `main` when `preserveMain` is true
- Empty/unnamed declarations

**Output structure:**

```dart
class RenameScope {
  /// Classes with their members, preserving the class→member relationship.
  final List<ClassScope> classes;

  /// Top-level procedures and fields (not in any class).
  final List<Member> topLevelMembers;

  /// Override families — groups of members that must share one name.
  final OverrideFamilies overrideFamilies;

  /// Local variables and parameters to rename.
  final List<VariableDeclaration> variables;
}

class ClassScope {
  final Class node;
  final List<Member> instanceMembers;
  final List<Member> staticMembers;
  final List<Constructor> constructors;
}
```

The scope gives the generator and allocator a complete picture of the codebase — structure and relationships — without exposing the raw AST.

### 2. Allocate — `NameGenerator` + `NameAllocator` → `RenameMapping`

Two components with distinct roles:

- **`NameGenerator`** — the creative part. Takes `RenameScope`, produces raw name strings for every slot. This is where strategy lives.
- **`NameAllocator`** — the plumbing. Takes raw names from the generator, wires them into kernel `Name` objects with correct privacy and library scope, builds the `RenameMapping`.

`NameAllocator` is one class, always the same. `NameGenerator` varies by strategy.

#### `NameGenerator` — the strategy

```dart
abstract class NameGenerator {
  /// Generate names for everything in [scope].
  ///
  /// Each slot in the scope gets a name string. The generator
  /// decides HOW to name things. The allocator decides how to
  /// WIRE them into the AST.
  Future<GeneratedNames> generate(RenameScope scope);
}
```

**Why `generate(scope)` and not `next()`?**

Simple generators don't need the scope — they just produce names from a pool. But the AI generator needs the **full picture** to produce semantically coherent names. It needs to see that a class has methods `connect`, `query`, `close` and name them as a coherent group that looks like a real codebase.

Simple generators iterate the scope mechanically:

```dart
class SequentialNameGenerator extends NameGenerator {
  @override
  Future<GeneratedNames> generate(RenameScope scope) async {
    var counter = 0;
    return GeneratedNames(
      familyNames: {
        for (final f in scope.overrideFamilies.families)
          f: _encode(counter++),
      },
      singletonNames: {
        for (final m in _allSingletons(scope)) m: _encode(counter++),
      },
      classNames: {
        for (final c in scope.classes) c.node: _encode(counter++),
      },
      variableNames: {
        for (final v in scope.variables) v: _encode(counter++),
      },
    );
  }
}
```

AI generator uses the structure:

```dart
class AiNameGenerator extends NameGenerator {
  @override
  Future<GeneratedNames> generate(RenameScope scope) async {
    // Serialize scope (classes, members, relationships) → prompt
    // API call → parse response → return GeneratedNames
  }
}
```

**Implementations:**

- `SequentialNameGenerator` — `a`, `b`, ..., `aa`, `ab`, ... (deterministic, good for tests)
- `ShuffledNameGenerator` — seeded random permutation (current default)
- `AiNameGenerator` (planned) — sends full scope to AI, gets back plausible names

#### `GeneratedNames` — generator output

```dart
class GeneratedNames {
  /// One name for each override family.
  final Map<OverrideFamily, String> familyNames;

  /// One name for each singleton member (top-level, static).
  final Map<Member, String> singletonNames;

  /// One name for each class.
  final Map<Class, String> classNames;

  /// One name for each variable.
  final Map<VariableDeclaration, String> variableNames;
}
```

Raw strings only. No privacy prefixes, no kernel `Name` objects. The generator produces bare names like `connect`, `foo`, `a`. The allocator adds `_` prefixes and library scope.

#### `NameAllocator` — the bridge

One class. Not sealed, not subclassed.

**What it handles (same for all strategies):**

- Expands family names → one `Name` per member in the family
- Adds `_` prefix for private members + sets library scope
- Passes through class and variable names
- Builds the `symbolMap` (original → obfuscated) alongside the AST maps

```dart
class NameAllocator {
  RenameMapping allocate(RenameScope scope, GeneratedNames names) {
    final members = <Member, Name>{};
    final symbolMap = <String, String>{};

    // Expand families: one generated name → all members in the family.
    for (final family in scope.overrideFamilies.families) {
      final rawName = names.familyNames[family]!;
      final name = family.isPrivate
          ? Name('_$rawName', family.libraryScope)
          : Name(rawName);
      for (final member in family.members) {
        members[member] = name;
        symbolMap[memberNameText(member)] = name.text;
      }
    }

    // Singletons, classes, variables — similar wiring + symbolMap.
    // ...

    return RenameMapping(
      members: members,
      classes: names.classNames,
      variables: names.variableNames,
      symbolMap: symbolMap,
    );
  }
}
```

#### Output — `RenameMapping`

```dart
class RenameMapping {
  /// AST-level maps (used by the applier to mutate the tree).
  final Map<Member, Name> members;
  final Map<Class, String> classes;
  final Map<VariableDeclaration, String> variables;

  /// Serializable form: original name → obfuscated name.
  /// Built during allocation so it's available even after the
  /// component is discarded.
  final Map<String, String> symbolMap;

  /// Export as JSON for file dumping.
  String toJson() { ... }
}
```

`RenameMapping` is the pass result — returned to the caller for file dumping (symbol map), debugging, or further processing. The `symbolMap` is a plain `Map<String, String>` that survives beyond the component's lifetime.

### 3. Apply — `RenameApplier`

Takes `RenameMapping` and mutates the AST. Pure mechanical work.

**What it does:**

- Renames declarations (class names, member names, variable names)
- Updates call sites (InstanceGet, InstanceSet, InstanceInvocation, etc.)
- Unbinds canonical names for renamed libraries

**What it does NOT do:**

- Decide what to rename (that's the collector)
- Generate names (that's the generator)
- Wire names into kernel objects (that's the allocator)

## Data Flow

```
Component + Options + Target
       │
       ▼
  ┌──────────────────────────────────────────────────┐
  │  Collector (orchestrates 3 sub-components)        │
  │    DeclarationCollector ──▶ raw declarations      │
  │    ClassRelationIndex   ──▶ hierarchy             │
  │    OverrideFamilyAnalyzer ──▶ families            │
  └──────────────────────────────────────────────────┘
       │
       ▼
  RenameScope (structured declarations + families)
       │
       ▼
  ┌─────────────┐
  │  Generator   │──▶ GeneratedNames (raw name strings)
  └─────────────┘
       │
       ▼
  ┌─────────────┐
  │  Allocator   │──▶ RenameMapping (AST maps + symbolMap)
  └─────────────┘
       │
       ▼
  ┌─────────────┐
  │   Applier    │──▶ Mutated Component
  └─────────────┘
       │
       ▼
  Result<RenameMapping>  (returned to caller)
```

Each step has a single input and a single output. No shared mutable state.

## File Layout

```
lib/src/engine/passes/rename/
├── rename_pass.dart              # Orchestrator (dumb wiring)
├── rename_collector.dart         # Collection orchestrator
├── declaration_collector.dart    # AST walk — raw declarations
├── rename_scope.dart             # Data: ClassScope, RenameScope
├── name_generator.dart           # Abstract NameGenerator + GeneratedNames
├── name_allocator.dart           # Bridge: GeneratedNames → RenameMapping
├── rename_mapping.dart           # Data: AST maps + serializable symbolMap
├── rename_applier.dart           # Phase 3: RenameMapping → mutated AST
├── rename_helpers.dart           # Shared utilities
├── override_family/
│   ├── override_family_analyzer.dart  # Union-Find family grouping
│   ├── override_families.dart         # Data: OverrideFamilies, OverrideFamily
│   └── class_relation_index.dart      # Class hierarchy index
└── generators/
    ├── sequential_generator.dart      # a, b, ..., aa, ab, ...
    └── shuffled_generator.dart        # Seeded random permutation
```

## Override Families

### The Problem

In Dart, when a subclass overrides a method, the kernel AST dispatches calls by `Name`. If `Animal.speak` is renamed to `x` but `Dog.speak` is renamed to `y`, then `(animal as Animal).speak()` resolves to `x` — but the `Dog` instance only has `y`. Crash.

**Rule: members connected by inheritance must get the same obfuscated name.**

This applies to:
- Direct overrides (`Dog.speak` overrides `Animal.speak`)
- Transitive chains (`Poodle → Dog → Animal`)
- Diamond inheritance (`class C implements A, B` — if both A and B declare `foo`, all three must match)
- Interface conformance (`implements` is the same as `extends` for this purpose)
- Private members (scoped per library — `_foo` in lib A is unrelated to `_foo` in lib B)

This does **NOT** apply to:
- Static members (dispatched by reference, not by name)
- Top-level functions (no inheritance)
- Constructors (dispatched by reference)

### Architecture

`OverrideFamilyAnalyzer` does ONE thing: takes already-collected classes and their instance members, groups them by name equivalence under inheritance.

```dart
class OverrideFamilyAnalyzer {
  /// Input: class scopes (already collected, already filtered).
  /// Output: families — groups of members that must share a name.
  OverrideFamilies analyze(
    List<ClassScope> classes,
    ClassRelationIndex hierarchy,
  );
}
```

No `Component`, no `ObfuscationTarget`, no singleton collection. Just classes in, families out.

**`OverrideFamilies`** — richer output:

```dart
class OverrideFamilies {
  /// Each family is a set of members that must share one name.
  final List<OverrideFamily> families;

  /// Quick lookup: which family does this member belong to?
  final Map<Member, OverrideFamily> familyOf;
}

class OverrideFamily {
  /// All members in this family.
  final Set<Member> members;

  /// The root member (declared highest in the hierarchy).
  final Member root;

  /// Whether all members are private (determines `_` prefix).
  final bool isPrivate;

  /// Library scope for private families.
  final Library? libraryScope;
}
```

The generator can reason about families as objects — it knows the root member, privacy, and all participants. Useful for AI naming ("this family is rooted in `Animal.speak`, let me pick a verb").

**`ClassRelationIndex`** stays as a utility. Key queries: `areRelated(a, b)` and `shareDeclaringSupertypeForName(a, b, name)`. Internal representation can be optimized later without changing the interface.

## Decisions

1. **`RenameScope` is rich from day one** — `ClassScope` wrappers, override families. Provides a complete picture to any generator strategy.

2. **`RenameMapping` carries a serializable `symbolMap`** — `Map<String, String>` (original → obfuscated) built during allocation. Survives beyond the AST component's lifetime. Supports JSON export for file dumping.

3. **Override family analysis is derived, not collected** — `OverrideFamilyAnalyzer` takes already-collected `ClassScope` data and groups instance members. No `Component` or target access needed.

4. **`OverrideFamily` is a real object, not an opaque ID** — carries root member, privacy flag, library scope, and all participants.

5. **Call graph is a future addition** — the `RenameScope` interface will support
   it (see [../archive/call-graph.md](../archive/call-graph.md)) but it's not
   built until the AI generator needs it.

6. **Async from the start** — `NameGenerator.generate()` and `Pass.run()` return `Future`. Simple generators complete synchronously but the interface supports async (AI API calls) without refactoring.

7. **Collection is three small components** — `DeclarationCollector` (AST walk), `ClassRelationIndex` (hierarchy), `OverrideFamilyAnalyzer` (families). Each single-purpose, each independently testable. `RenameCollector` orchestrates them.
