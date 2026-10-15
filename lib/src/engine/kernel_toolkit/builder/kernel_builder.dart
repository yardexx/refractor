import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/sdk/sdk_index.dart';

/// Builds kernel expression nodes without hand-assembling the IL.
///
/// Per-site inline obfuscation (opaque predicates, arithmetic mangling, dead
/// code) generates fresh expressions at each site. Doing that against raw
/// kernel means every operator is an [InstanceInvocation] carrying an interface
/// target and a function type — the same verbosity that made the string-decode
/// helper 350 lines of IL. [KernelBuilder] wraps that so a generator can write
/// `b.and(cond, b.ge(b.mul(k, k), b.intLit(0)))` and leave the resolution to
/// the builder. It models `int`/`num` operators (operands and results typed as
/// `int`, as the SDK does for `int` receivers) plus Dart's built-in logical
/// nodes.
///
/// It resolves SDK operators once per component, so reuse one builder across a
/// component rather than constructing one per site.
class KernelBuilder {
  KernelBuilder(Component component) : _sdk = SdkIndex(component);

  final SdkIndex _sdk;

  late final Class _intClass = _sdk.requireClass('dart:core', 'int');
  late final Class _numClass = _sdk.requireClass('dart:core', 'num');
  late final InterfaceType _intType = _sdk.interfaceType(_intClass);
  late final InterfaceType _boolType = _sdk.interfaceType(
    _sdk.requireClass('dart:core', 'bool'),
  );

  /// The `int` type, e.g. for typing temporaries bound around an expression.
  DartType get intType => _intType;

  /// An `int` literal.
  IntLiteral intLit(int value) => IntLiteral(value);

  /// A `bool` literal.
  BoolLiteral boolLit({required bool value}) => BoolLiteral(value);

  /// `a * b` on `int`.
  Expression mul(Expression a, Expression b) => _arithmetic('*', a, b);

  /// `a + b` on `int`.
  Expression add(Expression a, Expression b) => _arithmetic('+', a, b);

  /// `a - b` on `int`.
  Expression sub(Expression a, Expression b) => _arithmetic('-', a, b);

  /// `a % b` on `int`.
  Expression mod(Expression a, Expression b) => _arithmetic('%', a, b);

  /// `a ^ b` on `int` (bitwise xor).
  Expression xor(Expression a, Expression b) => _arithmetic('^', a, b);

  /// `a & b` on `int` (bitwise and).
  Expression bitAnd(Expression a, Expression b) => _arithmetic('&', a, b);

  /// `a << b` on `int` (left shift).
  Expression shl(Expression a, Expression b) => _arithmetic('<<', a, b);

  /// `a >= b` (result `bool`).
  Expression ge(Expression a, Expression b) => _comparison('>=', a, b);

  /// `a > b` (result `bool`).
  Expression gt(Expression a, Expression b) => _comparison('>', a, b);

  /// `a <= b` (result `bool`).
  Expression le(Expression a, Expression b) => _comparison('<=', a, b);

  /// `a < b` (result `bool`).
  Expression lt(Expression a, Expression b) => _comparison('<', a, b);

  /// `a && b`.
  Expression and(Expression a, Expression b) =>
      LogicalExpression(a, LogicalExpressionOperator.AND, b);

  /// `a || b`.
  Expression or(Expression a, Expression b) =>
      LogicalExpression(a, LogicalExpressionOperator.OR, b);

  /// `!a`.
  Expression not(Expression a) => Not(a);

  Expression _arithmetic(String op, Expression a, Expression b) =>
      _invoke(op, a, b, _intType);

  Expression _comparison(String op, Expression a, Expression b) =>
      _invoke(op, a, b, _boolType);

  Expression _invoke(
    String op,
    Expression receiver,
    Expression argument,
    DartType returnType,
  ) {
    final target = _operator(op);
    return InstanceInvocation(
      InstanceAccessKind.Instance,
      receiver,
      Name(op),
      Arguments([argument]),
      interfaceTarget: target,
      functionType: FunctionType(
        [_intType],
        returnType,
        Nullability.nonNullable,
      ),
    );
  }

  /// The operator procedure for [op], taken from `int` if it declares it, else
  /// `num` (comparisons live on `num`, arithmetic on `int`).
  Procedure _operator(String op) {
    for (final cls in [_intClass, _numClass]) {
      for (final procedure in cls.procedures) {
        if (procedure.name.text == op) return procedure;
      }
    }
    throw ArgumentError('No int/num operator "$op" found.');
  }
}
