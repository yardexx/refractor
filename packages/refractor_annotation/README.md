# refractor_annotation

[![Dart SDK](https://img.shields.io/badge/Dart-3.11.3-blue.svg)](https://dart.dev/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Lightweight source annotations for Refractor.

This package exists so application code can use Refractor-owned annotations
without depending on the Refractor CLI package.

## Usage

```dart
import 'package:refractor_annotation/refractor_annotation.dart';

@Refractor.keep()
class PublicApi {}

class EntryPointService {
  @Refractor.keep()
  String callback({required String label, bool excited = false}) {
    return excited ? 'entry:$label!' : 'entry:$label';
  }
}
```

## API

This package exports:

- `Refractor`
- `RefractorKeep`

## License

MIT. See [LICENSE](LICENSE).
