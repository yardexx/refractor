/// Collects heterogeneous results from pass runs.
///
/// The engine asks for specific results by pass name + type:
/// ```dart
/// final mapping = results.get<RenameMapping>('rename');
/// ```
class PassResults {
  final Map<String, Object?> _results = {};

  /// Store a pass result. Null results are ignored.
  void add(String passName, Object? result) {
    if (result != null) _results[passName] = result;
  }

  /// Retrieve a result by pass name, cast to [T].
  T? get<T>(String passName) => _results[passName] as T?;
}
