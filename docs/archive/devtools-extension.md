# Feature: DevTools Extension

Dart DevTools extension that visualizes obfuscation results inside the IDE. No other obfuscation tool in any ecosystem offers IDE-integrated visualization.

---

## Architecture

A DevTools extension is a **Flutter web app** embedded as an iframe tab in Dart DevTools. It appears alongside Inspector, Performance, Memory, etc.

```
┌─────────────────────────────────────────────┐
│ Dart DevTools                               │
├────┬────┬────┬────┬────┬───────────────┬────┤
│ 🔍 │ ⚡ │ 🧠 │ 📊 │ 🔧 │  Refractor    │ ...│
│    │    │    │    │    │  [active tab]  │    │
├────┴────┴────┴────┴────┴───────────────┴────┤
│                                             │
│  ┌─ Build Summary ────────────────────────┐ │
│  │ Last build: 2026-03-17 14:32           │ │
│  │ Passes: rename, string_encrypt         │ │
│  │ Symbols renamed: 142 (87% coverage)    │ │
│  │ Strings encrypted: 38/41 (3 const)     │ │
│  └────────────────────────────────────────┘ │
│                                             │
│  ┌─ Symbol Map ───────────────────────────┐ │
│  │ 🔍 Search: [computeComplex___]        │ │
│  │                                        │ │
│  │ Original          Obfuscated    Type   │ │
│  │ Application       J             class  │ │
│  │ computeComplex... M             func   │ │
│  │ dangerousOper...  X             func   │ │
│  │ appName           i             field  │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

### Communication Model

The extension does NOT need a running app. It reads build artifacts from the project workspace via the **Dart Tooling Daemon (DTD)**.

```
refractor build
    │
    ├── build/refractor/build_summary.json    ← stats, config, timestamp
    ├── build/refractor/symbol_map.json       ← enriched name mappings
    └── build/refractor/coverage.json         ← per-pass coverage data
                    │
                    ▼
         DevTools Extension
         (reads via DTD FileSystem API)
```

### Package Structure

```
packages/
  refractor_devtools_extension/     # Extension source (Flutter web app)
    lib/
      main.dart                     # Entry point
      src/
        views/
          build_summary_view.dart
          symbol_map_view.dart
          coverage_view.dart
        models/
          build_summary.dart
          symbol_entry.dart
        services/
          artifact_reader.dart       # Reads JSON via DTD
    pubspec.yaml
    analysis_options.yaml

refractor/                          # Main package
  extension/
    devtools/
      config.yaml                   # Extension metadata
      build/                        # Pre-compiled Flutter web assets
```

### config.yaml

```yaml
name: refractor
issueTracker: https://github.com/yardexx/refractor/issues
version: 0.1.0
materialIconCodePoint: '0xe8d8'
requiresConnection: false
```

`requiresConnection: false` is the key — the extension works without a running app, loading build artifacts from disk.

---

## Engine Changes Required

Refractor's build pipeline must emit structured JSON artifacts.

### build_summary.json

```json
{
  "version": "0.2.0",
  "timestamp": "2026-03-17T14:32:00Z",
  "config": {
    "passes": ["rename", "string_encrypt"],
    "seed": 1337
  },
  "stats": {
    "rename": {
      "classes_renamed": 8,
      "members_renamed": 42,
      "variables_renamed": 67,
      "members_skipped_sdk": 12,
      "members_skipped_pragma": 2
    },
    "string_encrypt": {
      "strings_encrypted": 38,
      "strings_skipped_const": 3,
      "strings_skipped_pattern": 0
    }
  }
}
```

### symbol_map.json (enriched)

Current format is `{"obfuscated": "original"}`. Enrich to:

```json
{
  "entries": [
    {
      "original": "Application",
      "obfuscated": "J",
      "kind": "class",
      "library": "package:app/main.dart"
    },
    {
      "original": "computeComplexValue",
      "obfuscated": "M",
      "kind": "procedure",
      "library": "package:app/main.dart",
      "owner": "top-level"
    },
    {
      "original": "appName",
      "obfuscated": "i",
      "kind": "field",
      "library": "package:app/main.dart",
      "owner": "AppConfig"
    }
  ]
}
```

---

## MVP Scope (v0.4.2)

### Build Summary Dashboard
- Cards showing: last build timestamp, passes applied, total symbols renamed, string encryption coverage
- Color-coded badges: green (>80% coverage), yellow (50-80%), red (<50%)
- Config summary: seed, excluded patterns

### Symbol Map Browser
- Searchable table with columns: original name, obfuscated name, kind, owner, library
- Search by either original or obfuscated name (critical for debugging crash logs)
- Filter by kind (class, method, field, variable)
- Copy-to-clipboard for individual entries
- Sort by any column

---

## Enhanced Scope (v0.4.3)

### String Encryption Coverage
- List of all string literals found in the project
- Status per string: encrypted, skipped (const), skipped (pattern), skipped (SDK)
- Explanation for each skip ("const context — cannot encrypt")

### Protection Score
- Pie chart: % of identifiers renamed vs preserved (SDK, pragma, external)
- Pie chart: % of strings encrypted vs skipped
- Bar chart: coverage per library
- Overall score: "Protection Level: 87%"

### Build Diff
- Compare current vs previous build artifacts
- Show: new symbols added, symbols renamed differently, coverage changes
- Useful for incremental development

---

## Technical Constraints

1. **No `dart:io`** — extension runs as Flutter web. All file access through DTD.
2. **DTD requires Dart SDK >= 3.5** — document this requirement.
3. **Pre-compiled assets** — `extension/devtools/build/` ships compiled web app (~2-5 MB). Use `.pubignore` to keep out of git, include in `pub publish`.
4. **Development workflow** — use `--dart-define=use_simulated_environment=true` for hot restart during development.
5. **Version coupling** — `devtools_extensions` package tracks Flutter stable. Rebuild when Flutter updates.

---

## Dependencies

```yaml
dependencies:
  devtools_extensions: ^0.5.0
  devtools_app_shared: ^0.5.0
  flutter:
    sdk: flutter
```

---

## References

- Official docs: https://docs.flutter.dev/tools/devtools/extensions
- `devtools_extensions` package: https://pub.dev/packages/devtools_extensions
- `devtools_app_shared` package: https://pub.dev/packages/devtools_app_shared
- Official example: https://github.com/flutter/devtools/tree/master/packages/devtools_extensions/example
- Video: https://www.youtube.com/watch?v=gOrSc4s4RWY
