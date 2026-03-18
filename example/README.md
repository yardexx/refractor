A sample command-line application that doubles as an obfuscation edge-case
fixture.

It exercises:
- named-argument renaming
- dynamic get/set/invocation
- mixins and overrides
- SDK override exclusions
- local, instance, top-level, static-field, constructor, and factory tear-offs
- generic instantiations and redirecting factories
- `@pragma('vm:entry-point')` exclusions
- string interpolation and annotation-bearing declarations

Some edge cases are intentionally kept as source-only fixtures instead of being
executed at runtime, because the current obfuscated AOT build does not yet
support them safely:
- top-level function tear-off aliases
- generic top-level tear-off aliases
- constructor tear-off aliases
- redirecting factory tear-off aliases
- instantiated redirecting factory tear-off aliases
- instance-method tear-off aliases
- mutable function aliases
- final static-field aliases to top-level functions
- final static-field aliases to redirecting factories

Run it with:

```sh
dart run bin/app.dart --verbose
```
