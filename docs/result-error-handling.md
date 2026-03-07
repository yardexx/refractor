# Result-based error handling across commands

## Context

Currently error handling is split: `RefractorEngine.run()` returns `Result<BuildResult>` but `ConfigManager.loadConfig()` throws, and commands rely on exceptions bubbling up to a big try-catch in `RefractorCommandRunner`. The goal is to make failable operations return `Result` so commands can pattern-match on outcomes and return exit codes directly — cleaner, more explicit control flow.

## Changes

### 1. Extend `Result<T>` with convenience methods

**File:** `lib/src/utils/result.dart`

Add an extension with:
- `map<U>(U Function(T) f)` → transforms Ok value
- `flatMap<U>(Result<U> Function(T) f)` → chains Results

### 2. Add `exitFromError` helper to `RefractorCommand`

**File:** `lib/src/cli/commands/refractor_command.dart`

```dart
int exitFromError(Exception error) {
  if (error is RefractorException) {
    logger.err(error.message);
    if (error.cause != null) logger.detail('Caused by: ${error.cause}');
    return error.exitCode;
  }
  logger.err('An unexpected error occurred: $error');
  return ExitCode.software.code;
}
```

Commands use this in `Error` branches instead of throwing.

### 3. `ConfigManager.loadConfig` → returns `Result<RefractorConfig>`

**File:** `lib/src/config/config_manager.dart`

Replace `throw ConfigException(...)` with `return Result.error(ConfigException(...))` and wrap successful return in `Result.ok(...)`.

### 4. `RefractorEngine.run` → catch exceptions into `Result.error`

**File:** `lib/src/engine/engine.dart`

Wrap the body in `try { ... } on Exception catch (e) { return Result.error(e); }` so the return type is honest — currently exceptions from compiler/IO propagate as throws despite the `Result` return type.

### 5. Rewrite `BuildCommand.run` with Result pattern matching

**File:** `lib/src/cli/commands/build_command.dart`

```dart
final configResult = ConfigManager.loadConfig();
final config = switch (configResult) {
  Ok(:final value) => value,
  Error(:final error) => return exitFromError(error),
};
// ... build request ...
final result = engine.run(request: request, config: config);
switch (result) {
  case Ok(:final value):
    value.symbolTable.writeToFile(config.symbolMapPath);
    logger.success('Build complete: ${value.outputPath}');
    return ExitCode.success.code;
  case Error(:final error):
    return exitFromError(error);
}
```

No more `throw BuildException(...)` — direct exit code return.

### 6. Rewrite `InspectCommand.run` with Result pattern matching

**File:** `lib/src/cli/commands/inspect_command.dart`

`FileKernelIO().load()` throws `FileIoException`. Wrap in try-catch and use `exitFromError`. (This stays try-catch since `KernelIO.load` is not being changed to Result — it's an engine-internal interface.)

### 7. `InitCommand` — no change

It doesn't extend `RefractorCommand` (extends `Command<int>` directly) and doesn't call config/engine. Leave as-is.

### 8. Update tests

**`test/config/config_manager_test.dart`** (6 tests):
- 3 tests using `throwsA(isA<ConfigException>())` → check for `isA<Error<RefractorConfig>>()` and verify inner error
- 3 tests accessing `config` directly → unwrap from `Ok`

**`test/cli/commands/build_command_test.dart`**:
- `throws ConfigException` test → expect a non-zero exit code return instead of a throw

**`test/engine/refractor_engine_test.dart`** — no changes needed (engine still returns Result)

## What stays unchanged

- `RefractorCommandRunner.run()` try-catch — stays as safety net for truly unexpected errors
- `RefractorConfig.fromYaml` — internal parsing, keeps throwing (ConfigManager wraps it)
- `KernelIO`, `Compiler` interfaces — stay throwing (engine wraps them)
- `InitCommand` — self-contained, no config/engine calls
