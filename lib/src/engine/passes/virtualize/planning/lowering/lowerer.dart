import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/vm_ir.dart';

/// Lowers an eligible kernel [FunctionNode] to a [VmProgram], or returns null
/// if the function is outside the M0 subset (in which case it is left intact).
///
/// M0 grammar (conservative, correctness over coverage):
///  - All positional parameters typed `int`; no named/optional params.
///  - Return type `int` or `bool`.
///  - Body is a single `return <expr>;` (expression- or block-bodied).
///  - Expressions over params + int/bool literals using:
///    `+ - * ^ & | << >> ~` (int), `== != < <= > >=`, `! && ||`, ternary `?:`,
///    unary `-`.
///  - No locals, loops, calls, strings, doubles, fields, or null.
VmProgram? lowerFunction(FunctionNode function) {
  if (function.namedParameters.isNotEmpty) return null;
  if (function.requiredParameterCount != function.positionalParameters.length) {
    return null; // optional positional params unsupported in M0
  }
  for (final p in function.positionalParameters) {
    if (!_isIntType(p.type)) return null;
  }
  final returnsBool = _isBoolType(function.returnType);
  if (!returnsBool && !_isIntType(function.returnType)) return null;

  final body = function.body;
  final returnExpr = _soleReturnExpression(body);
  if (returnExpr == null) return null;

  final paramIndex = <VariableDeclaration, int>{
    for (var i = 0; i < function.positionalParameters.length; i++)
      function.positionalParameters[i]: i,
  };

  final lowerer = _Lowerer(paramIndex);
  if (!lowerer.lower(returnExpr)) return null;
  lowerer.emit(const VmInstr(VmOp.ret));

  return VmProgram(
    items: lowerer.items,
    argCount: function.positionalParameters.length,
    returnsBool: returnsBool,
  );
}

Expression? _soleReturnExpression(Statement? body) {
  if (body is ReturnStatement) return body.expression;
  if (body is Block &&
      body.statements.length == 1 &&
      body.statements.single is ReturnStatement) {
    return (body.statements.single as ReturnStatement).expression;
  }
  return null;
}

final class _Lowerer {
  _Lowerer(this._paramIndex);

  final Map<VariableDeclaration, int> _paramIndex;
  final List<Object> items = <Object>[];
  int _nextLabel = 0;

  void emit(VmInstr instr) => items.add(instr);
  VmLabel _label() => VmLabel(_nextLabel++);
  void _place(VmLabel label) => items.add(label);

  /// Lowers [e], leaving its value on the operand stack. Returns false (bail)
  /// on any unsupported construct.
  bool lower(Expression e) {
    if (e is IntLiteral) {
      emit(VmInstr(VmOp.pushConst, imm: e.value));
      return true;
    }
    if (e is BoolLiteral) {
      emit(VmInstr(VmOp.pushConst, imm: e.value ? 1 : 0));
      return true;
    }
    if (e is ConstantExpression) {
      final c = e.constant;
      if (c is IntConstant) {
        emit(VmInstr(VmOp.pushConst, imm: c.value));
        return true;
      }
      if (c is BoolConstant) {
        emit(VmInstr(VmOp.pushConst, imm: c.value ? 1 : 0));
        return true;
      }
      return false;
    }
    if (e is VariableGet) {
      final index = _paramIndex[e.variable];
      if (index == null) return false;
      emit(VmInstr(VmOp.pushArg, imm: index));
      return true;
    }
    if (e is Not) {
      // !x  ==  (x == 0)
      if (!lower(e.operand)) return false;
      emit(const VmInstr(VmOp.pushConst, imm: 0));
      emit(const VmInstr(VmOp.cmpEq));
      return true;
    }
    if (e is LogicalExpression) {
      return _lowerLogical(e);
    }
    if (e is ConditionalExpression) {
      return _lowerConditional(e.condition, e.then, e.otherwise);
    }
    if (e is EqualsCall) {
      if (!lower(e.left)) return false;
      if (!lower(e.right)) return false;
      emit(const VmInstr(VmOp.cmpEq));
      return true;
    }
    if (e is InstanceInvocation) {
      return _lowerInstanceInvocation(e);
    }
    return false;
  }

  bool _lowerInstanceInvocation(InstanceInvocation e) {
    final name = e.name.text;
    final args = e.arguments;
    if (args.named.isNotEmpty || args.types.isNotEmpty) return false;

    // Unary operators: receiver.op()
    if (args.positional.isEmpty) {
      switch (name) {
        case '~':
          if (!lower(e.receiver)) return false;
          emit(const VmInstr(VmOp.not));
          return true;
        case 'unary-':
          // -a  ==  0 - a
          emit(const VmInstr(VmOp.pushConst, imm: 0));
          if (!lower(e.receiver)) return false;
          emit(const VmInstr(VmOp.sub));
          return true;
        default:
          return false;
      }
    }

    // Binary operators: receiver.op(arg)
    if (args.positional.length != 1) return false;
    final op = _binaryOpFor(name);
    if (op == null) return false;
    if (!lower(e.receiver)) return false;
    if (!lower(args.positional.single)) return false;
    emit(VmInstr(op));
    return true;
  }

  VmOp? _binaryOpFor(String name) => switch (name) {
    '+' => VmOp.add,
    '-' => VmOp.sub,
    '*' => VmOp.mul,
    '^' => VmOp.xor,
    '&' => VmOp.and,
    '|' => VmOp.or,
    '<<' => VmOp.shl,
    '>>' => VmOp.shr,
    '<' => VmOp.cmpLt,
    '<=' => VmOp.cmpLe,
    '>' => VmOp.cmpGt,
    '>=' => VmOp.cmpGe,
    '==' => VmOp.cmpEq,
    '!=' => VmOp.cmpNe,
    _ => null,
  };

  bool _lowerLogical(LogicalExpression e) {
    // a && b  ==  a ? b : false ;  a || b  ==  a ? true : b
    final isAnd = e.operatorEnum == LogicalExpressionOperator.AND;
    final thenExpr = isAnd ? e.right : null;
    final elseExpr = isAnd ? null : e.right;
    final lElse = _label();
    final lEnd = _label();
    if (!lower(e.left)) return false;
    emit(VmInstr(VmOp.jz, target: lElse.id));
    // then branch
    if (isAnd) {
      if (!lower(thenExpr!)) return false;
    } else {
      emit(const VmInstr(VmOp.pushConst, imm: 1)); // true
    }
    emit(VmInstr(VmOp.jmp, target: lEnd.id));
    _place(lElse);
    if (isAnd) {
      emit(const VmInstr(VmOp.pushConst, imm: 0)); // false
    } else {
      if (!lower(elseExpr!)) return false;
    }
    _place(lEnd);
    return true;
  }

  bool _lowerConditional(
    Expression condition,
    Expression then,
    Expression otherwise,
  ) {
    final lElse = _label();
    final lEnd = _label();
    if (!lower(condition)) return false;
    emit(VmInstr(VmOp.jz, target: lElse.id));
    if (!lower(then)) return false;
    emit(VmInstr(VmOp.jmp, target: lEnd.id));
    _place(lElse);
    if (!lower(otherwise)) return false;
    _place(lEnd);
    return true;
  }
}

bool _isIntType(DartType type) =>
    type is InterfaceType &&
    type.classNode.name == 'int' &&
    type.classNode.enclosingLibrary.importUri.toString() == 'dart:core';

bool _isBoolType(DartType type) =>
    type is InterfaceType &&
    type.classNode.name == 'bool' &&
    type.classNode.enclosingLibrary.importUri.toString() == 'dart:core';
