A sample command-line application that doubles as an obfuscation edge-case
fixture.

It exercises:
- named-argument renaming
- dynamic get/set/invocation
- mixins and overrides
- SDK override exclusions
- local, instance, top-level, static-field, constructor, and factory tear-offs
- generic instantiations and redirecting factories
- `@Refractor.keep()` rename exclusions on entry-point-like surfaces
- ordinary source annotations alongside Refractor-owned keep annotations
- string interpolation and annotation-bearing declarations

The example keeps a few rename-sensitive declarations via:

```dart
import 'package:refractor_annotation/refractor_annotation.dart';

class EntryPointService {
  @Refractor.keep()
  String callback({required String label, bool excited = false}) { ... }
}
```

Run it with:

```sh
dart run bin/app.dart --verbose
```
