# Plan: Kernel Inspector — Flutter Desktop App

## Goal

Build a **standalone Flutter desktop app** (separate repo) that visualizes
compiled `.dill` file contents as an interactive node-flow graph using
`vyuh_node_flow`.

The refractor CLI `inspect` command stays as-is for terminal users.

---

## Project layout

Three independent repos:

```
refractor/                 (existing — CLI obfuscation tool)
kernel_model/              (NEW — shared pure-Dart library)
refractor_inspector/       (NEW — Flutter desktop app)
```

---

## Shared library: `kernel_model`

Separate repo. Pure Dart, no dart:io, no Flutter.

### Purpose

Convert `package:kernel` `Component` into a simple tree structure that both
the CLI and the Flutter app can consume. Without it, both projects duplicate
the same AST-walking, type-formatting, and annotation-formatting code (~200
lines).

### Data model

```dart
/// Root — one per .dill file.
class KernelTree {
  final String source;              // file path / label
  final List<KernelNode> libraries;
}

/// A single node in the tree.
sealed class KernelNode {
  String get id;                   // unique ID for graph wiring
  String get label;                // display text
  KernelNodeKind get kind;        // enum for theming
  List<String> get annotations;   // ["@pragma('vm:entry-point')", ...]
  List<KernelNode> get children;  // nested members
}

enum KernelNodeKind { library, classNode, procedure, field, constructor }

class LibraryNode extends KernelNode {
  final Uri importUri;
}

class ClassNode extends KernelNode {
  final String name;
  final bool isAbstract;
}

class ProcedureNode extends KernelNode {
  final String name;
  final String returnType;
  final String signature;         // "String fetchUser(int id)"
  final bool isStatic;
}

class FieldNode extends KernelNode {
  final String name;
  final String type;
  final bool isFinal;
  final bool isLate;
}

class ConstructorNode extends KernelNode {
  final String name;
  final String signature;
}
```

### Parser

```dart
class KernelParser {
  /// Parse a loaded Component into a KernelTree.
  KernelTree parse(Component component, {bool includeSdk = false});
}
```

### Text printer (for CLI)

```dart
class KernelTreePrinter {
  String print(KernelTree tree);
}
```

### File structure

```
kernel_model/
├── lib/
│   ├── kernel_model.dart             # barrel export
│   └── src/
│       ├── kernel_tree.dart
│       ├── kernel_node.dart
│       ├── kernel_parser.dart
│       └── kernel_tree_printer.dart
├── test/
│   ├── kernel_parser_test.dart
│   └── kernel_tree_printer_test.dart
├── pubspec.yaml
└── analysis_options.yaml
```

### Dependencies

```yaml
name: kernel_model
dependencies:
  kernel:
    path: ../refractor/third_party/kernel
```

### Impact on refractor CLI

Add `kernel_model` as path dep. `InspectCommand` shrinks to:

```dart
final component = FileKernelIO().load(path);
final tree = KernelParser().parse(component, includeSdk: showSdk);
logger.info(KernelTreePrinter().print(tree));
```

---

## Flutter app: `refractor_inspector`

Separate repo. Desktop-only Flutter app.

### Flow

1. Launch app (optionally pass `.dill` path as CLI arg)
2. Or pick a file via native file dialog
3. Load `.dill` with `FileKernelIO` / `loadComponentFromBinary`
4. Parse with `KernelParser` → `KernelTree`
5. Layout with Reingold-Tilford → positioned nodes
6. Render with `vyuh_node_flow` in read-only mode

### Node layout

Each `KernelNode` becomes a flow node. Parent→child = connection.

```
┌─────────────────────┐
│  package:app/main   │  ← LibraryNode
└──┬──────────────┬───┘
   │              │
   ▼              ▼
┌────────┐   ┌──────────────┐
│ main() │   │ UserService  │  ← ClassNode
└────────┘   └──┬───────┬───┘
                │       │
                ▼       ▼
          ┌──────────┐ ┌──────────────┐
          │fetchUser()│ │final _name   │
          └──────────┘ └──────────────┘
```

### Auto-layout — Reingold-Tilford

```dart
class TreeLayout {
  List<PositionedNode> layout(KernelTree tree, {
    double nodeWidth = 220,
    double nodeHeight = 80,
    double horizontalGap = 40,
    double verticalGap = 60,
  });
}
```

Pure Dart, no Flutter — testable independently.

### Screen layout

Single-screen app:

| Area | Widget | Purpose |
|---|---|---|
| Top bar | `AppBar` | File path, "Open" button, SDK toggle, search |
| Canvas | `NodeFlowViewer` | Read-only pannable/zoomable graph |
| Side panel | `NodeDetailPanel` | Full details of tapped node |

Use `NodeFlowViewer` (read-only) with `present` or `inspect` behavior mode.

### Node cards

Custom `nodeBuilder` renders each node as a `KernelNodeCard`:

| KernelNodeKind | Color | Icon |
|---|---|---|
| library | blue-grey | `Icons.folder` |
| classNode | indigo | `Icons.class_` |
| procedure | teal | `Icons.functions` |
| field | amber | `Icons.data_object` |
| constructor | purple | `Icons.build` |

### Side panel (on selection)

- Full name + return type / field type
- All annotations with values
- Modifiers (static, final, late, abstract)
- Import URI (libraries)
- Child count

### File structure

```
refractor_inspector/
├── lib/
│   ├── main.dart                          # entry, CLI arg or file picker
│   └── src/
│       ├── app.dart                       # MaterialApp + dark theme
│       ├── inspector_page.dart            # main scaffold
│       ├── layout/
│       │   └── tree_layout.dart           # Reingold-Tilford
│       ├── graph/
│       │   ├── kernel_graph_builder.dart   # KernelTree → nodes + connections
│       │   └── kernel_node_card.dart      # styled node widget
│       └── detail/
│           └── node_detail_panel.dart     # selection details
├── test/
│   ├── layout/tree_layout_test.dart
│   └── graph/kernel_graph_builder_test.dart
├── pubspec.yaml
└── analysis_options.yaml
```

### Dependencies

```yaml
name: refractor_inspector
dependencies:
  flutter:
    sdk: flutter
  vyuh_node_flow: ^0.27.3
  kernel_model:
    path: ../kernel_model
  kernel:
    path: ../refractor/third_party/kernel
  file_picker: ^8.0.0
```

### Platforms

Desktop only: macOS, Linux, Windows.

---

## Implementation order

### Phase 1 — `kernel_model`
1. Create package with pubspec
2. `KernelNode` sealed hierarchy + `KernelNodeKind`
3. `KernelTree`
4. `KernelParser` (extract from `InspectCommand`)
5. `KernelTreePrinter` (text output)
6. Tests against compiled fixture `.dill`

### Phase 2 — Integrate into refractor CLI
1. Add `kernel_model` path dep
2. Refactor `InspectCommand` → `KernelParser` + `KernelTreePrinter`
3. Verify existing tests pass

### Phase 3 — Flutter app scaffold
1. `flutter create --platforms=macos,linux,windows refractor_inspector`
2. Add deps
3. `main.dart` — CLI arg parsing + file picker fallback
4. Dark theme

### Phase 4 — Layout + graph
1. `TreeLayout` — Reingold-Tilford, unit tested
2. `KernelGraphBuilder` — tree → `NodeFlowController` nodes + connections
3. `KernelNodeCard` — styled per kind

### Phase 5 — Wire up
1. `InspectorPage` — load → parse → layout → render `NodeFlowViewer`
2. `NodeDetailPanel` — selection details
3. Fit-to-view on load

### Phase 6 — Polish (nice-to-have)
1. Search bar — find/highlight node by name
2. Collapse/expand subtrees
3. Before/after diff — two `.dill` files side by side
4. Export graph as PNG/SVG

---

## Open questions

1. **vyuh_node_flow vs alternatives?** — Powerful but pulls in MobX. If heavy:
   - `graphview` — simpler, built-in tree layout, less polish
   - Custom `InteractiveViewer` + `CustomPainter` — full control, more work
   - Recommendation: start with vyuh_node_flow, swap if needed

2. **`kernel` dependency** — Both `kernel_model` and the app need
   `third_party/kernel`. Simplest: sibling directories with path deps.
   Later: git dep pinned to SDK version.