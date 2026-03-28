class DeclarationPolicy {
  const DeclarationPolicy({
    this.excludeFromAllObfuscation = false,
    this.excludeFromRename = false,
    this.excludeFromStringEncryption = false,
    this.excludeParametersFromRename = false,
  });

  static const allow = DeclarationPolicy();

  final bool excludeFromAllObfuscation;
  final bool excludeFromRename;
  final bool excludeFromStringEncryption;
  final bool excludeParametersFromRename;

  bool get isRenameExcluded => excludeFromAllObfuscation || excludeFromRename;

  bool get isStringEncryptionExcluded =>
      excludeFromAllObfuscation || excludeFromStringEncryption;

  DeclarationPolicy merge(DeclarationPolicy other) {
    return DeclarationPolicy(
      excludeFromAllObfuscation:
          excludeFromAllObfuscation || other.excludeFromAllObfuscation,
      excludeFromRename: excludeFromRename || other.excludeFromRename,
      excludeFromStringEncryption:
          excludeFromStringEncryption || other.excludeFromStringEncryption,
      excludeParametersFromRename:
          excludeParametersFromRename || other.excludeParametersFromRename,
    );
  }
}
