import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/model/generated_names.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_scope.dart';
import 'package:refractor/src/engine/passes/rename/name_generator/name_generator.dart';

/// Generates names from a seeded random permutation.
///
/// Names are drawn from an alphabetic pool (`a`–`z`, `A`–`Z`, then `aa`–`zz`,
/// etc.) shuffled with a deterministic seed. Same seed + same call sequence
/// produces identical names.
class ShuffledGenerator extends NameGenerator {
  ShuffledGenerator({int? seed, String? projectName})
    : _seed = seed ?? _defaultSeed(projectName);

  final int _seed;
  late final List<int> _digitMap = _buildDigitMap(_seed);
  int _level = 1;
  int _indexInLevel = 0;
  int _levelSize = pow(_alphabetSize, 1).toInt();
  int? _multiplier;
  int? _offset;

  /// Returns the next name in the shuffled sequence.
  String nextName() {
    if (_indexInLevel >= _levelSize) {
      _level++;
      _indexInLevel = 0;
      _levelSize = pow(_alphabetSize, _level).toInt();
      _multiplier = null;
      _offset = null;
    }

    final permuted = _permuteIndex(_indexInLevel, _levelSize, _level);
    _indexInLevel++;
    return _encodeFixedWidth(permuted, _level);
  }

  @override
  Future<GeneratedNames> generate(RenameScope scope) async {
    final families = scope.overrideFamilies;

    return GeneratedNames(
      familyNames: {
        for (final f in families.families) f: nextName(),
      },
      singletonNames: {
        for (final m in _allSingletons(scope)) m: nextName(),
      },
      classNames: {
        for (final c in scope.classScopes) c.node: nextName(),
      },
      variableNames: {
        for (final v in scope.variables) v: nextName(),
      },
    );
  }

  static int _defaultSeed(String? projectName) =>
      _stableHash(projectName ?? 'refractor');

  static int _stableHash(String input) {
    final digest = sha256.convert(utf8.encode(input)).bytes;
    final seed =
        (digest[0] << 24) | (digest[1] << 16) | (digest[2] << 8) | digest[3];
    return seed & 0x7fffffff;
  }

  static List<int> _buildDigitMap(int seed) {
    return List<int>.generate(_alphabetSize, (i) => i)..shuffle(Random(seed));
  }

  int _permuteIndex(int index, int modulus, int level) {
    _multiplier ??= _chooseMultiplier(modulus, level);
    _offset ??= _chooseOffset(modulus, level);
    return ((_multiplier! * index) + _offset!) % modulus;
  }

  int _chooseMultiplier(int modulus, int level) {
    var candidate = (_stableHash('mul:$_seed:$level') % modulus).abs();
    if (candidate == 0) candidate = 1;
    while (candidate.gcd(modulus) != 1) {
      candidate = (candidate + 1) % modulus;
      if (candidate == 0) candidate = 1;
    }
    return candidate;
  }

  int _chooseOffset(int modulus, int level) {
    return (_stableHash('off:$_seed:$level') % modulus).abs();
  }

  String _encodeFixedWidth(int value, int width) {
    final codes = List<int>.filled(width, 0);
    var n = value;
    for (var pos = width - 1; pos >= 0; pos--) {
      final digit = n % _alphabetSize;
      n ~/= _alphabetSize;
      codes[pos] = _digitMap[digit];
    }
    return String.fromCharCodes([
      for (final digit in codes) _alphabet.codeUnitAt(digit),
    ]);
  }

  static const String _alphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const int _alphabetSize = 52;
}

/// Collects all singleton members (top-level + static) from a scope.
Iterable<Member> _allSingletons(RenameScope scope) sync* {
  yield* scope.topLevelMembers;
  for (final cs in scope.classScopes) {
    yield* cs.staticMembers;
    yield* cs.constructors;
  }
}
