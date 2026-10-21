import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/vm_ir.dart';

/// Synthesizes a per-function switch-loop bytecode interpreter as kernel and
/// injects it as a top-level `@pragma('vm:never-inline')` static procedure.
///
/// Signature of the injected helper:
///   `int _vm$N(List<int> code, List<int> args)`
///
/// Its semantics match `reference_interpreter.dart` exactly (same opcode
/// numbering, same 64-bit int arithmetic, same stack discipline), so the E6
/// differential gate is sound. M0 uses the canonical fixed ISA; per-build ISA
/// randomization + chained decode are M1.
final class InterpreterInjector {
  InterpreterInjector(Component component) : _ctx = _VmKernelContext(component);

  final _VmKernelContext _ctx;
  int _counter = 0;

  /// Injects an interpreter sized to [stackDepth] into [library]; returns it.
  Procedure inject(Library library, int stackDepth) {
    final code = VariableDeclaration('code', type: _ctx.listIntType);
    final args = VariableDeclaration('args', type: _ctx.listIntType);
    final stack = VariableDeclaration(
      'stack',
      type: _ctx.listIntType,
      initializer: StaticInvocation(
        _ctx.listFilled,
        Arguments(
          [IntLiteral(stackDepth), IntLiteral(0)],
          types: [_ctx.intType],
        ),
      ),
      isFinal: true,
    );
    final sp = VariableDeclaration(
      'sp',
      type: _ctx.intType,
      initializer: IntLiteral(0),
    );
    final pc = VariableDeclaration(
      'pc',
      type: _ctx.intType,
      initializer: IntLiteral(0),
    );

    final op = VariableDeclaration(
      'op',
      type: _ctx.intType,
      initializer: _lget(code, _ig(pc)),
      isFinal: true,
    );
    final swLabel = LabeledStatement(null);
    final sw = SwitchStatement(
      _ig(op),
      _buildCases(
        code: code,
        args: args,
        stack: stack,
        sp: sp,
        pc: pc,
        swLabel: swLabel,
      ),
    )..expressionType = _ctx.intType;
    swLabel.body = sw;
    sw.parent = swLabel;

    final loopBody = Block([
      op,
      _set(pc, _add1(_ig(pc))),
      swLabel,
    ]);
    final loop = WhileStatement(BoolLiteral(true), loopBody);

    final functionNode = FunctionNode(
      Block([stack, sp, pc, loop]),
      positionalParameters: [code, args],
      requiredParameterCount: 2,
      returnType: _ctx.intType,
    )..fileOffset = 0;
    final procedure = Procedure(
      Name(_freshName(), library),
      ProcedureKind.Method,
      functionNode,
      fileUri: library.fileUri,
      isStatic: true,
    )
      ..addAnnotation(_ctx.neverInlineAnnotation())
      ..fileOffset = 0
      ..fileEndOffset = 0;

    library.addProcedure(procedure);
    return procedure;
  }

  List<SwitchCase> _buildCases({
    required VariableDeclaration code,
    required VariableDeclaration args,
    required VariableDeclaration stack,
    required VariableDeclaration sp,
    required VariableDeclaration pc,
    required LabeledStatement swLabel,
  }) {
    Statement brk() => BreakStatement(swLabel);
    Expression stackAt(Expression idx) => _lget(stack, idx);
    Expression spMinus(int n) =>
        n == 0 ? _ig(sp) : _bin(_ig(sp), '-', _ctx.sub, IntLiteral(n));
    Statement setStack(Expression idx, Expression val) =>
        _lsetStmt(stack, idx, val);
    Statement decSp() => _set(sp, _bin(_ig(sp), '-', _ctx.sub, IntLiteral(1)));
    Statement incSp() => _set(sp, _add1(_ig(sp)));
    Statement incPc() => _set(pc, _add1(_ig(pc)));

    // Binary op case: sp--; stack[sp-1] = stack[sp-1] OP stack[sp];
    SwitchCase binaryCase(int opcode, String name, Procedure target) {
      return _case(
        opcode,
        Block([
          decSp(),
          setStack(
            spMinus(1),
            _bin(stackAt(spMinus(1)), name, target, stackAt(spMinus(0))),
          ),
          brk(),
        ]),
      );
    }

    // Comparison case: sp--; stack[sp-1] = (stack[sp-1] CMP stack[sp]) ? 1 : 0;
    SwitchCase compareCase(
      int opcode,
      Expression Function(Expression a, Expression b) cmp,
    ) {
      return _case(
        opcode,
        Block([
          decSp(),
          setStack(
            spMinus(1),
            ConditionalExpression(
              cmp(stackAt(spMinus(1)), stackAt(spMinus(0))),
              IntLiteral(1),
              IntLiteral(0),
              _ctx.intType,
            ),
          ),
          brk(),
        ]),
      );
    }

    const n = kOpcodeNumbers;
    return [
      // pushConst: stack[sp] = code[pc]; pc++; sp++;
      _case(
        n[VmOp.pushConst]!,
        Block([
          setStack(_ig(sp), _lget(code, _ig(pc))),
          incPc(),
          incSp(),
          brk(),
        ]),
      ),
      // pushArg: stack[sp] = args[code[pc]]; pc++; sp++;
      _case(
        n[VmOp.pushArg]!,
        Block([
          setStack(_ig(sp), _lget(args, _lget(code, _ig(pc)))),
          incPc(),
          incSp(),
          brk(),
        ]),
      ),
      binaryCase(n[VmOp.add]!, '+', _ctx.add),
      binaryCase(n[VmOp.sub]!, '-', _ctx.sub),
      binaryCase(n[VmOp.mul]!, '*', _ctx.mul),
      binaryCase(n[VmOp.xor]!, '^', _ctx.xor),
      binaryCase(n[VmOp.and]!, '&', _ctx.and),
      binaryCase(n[VmOp.or]!, '|', _ctx.or),
      binaryCase(n[VmOp.shl]!, '<<', _ctx.shl),
      binaryCase(n[VmOp.shr]!, '>>', _ctx.shr),
      // not: stack[sp-1] = ~stack[sp-1];
      _case(
        n[VmOp.not]!,
        Block([
          setStack(spMinus(1), _bitNot(stackAt(spMinus(1)))),
          brk(),
        ]),
      ),
      compareCase(n[VmOp.cmpEq]!, _eq),
      compareCase(n[VmOp.cmpNe]!, (a, b) => Not(_eq(a, b))),
      compareCase(n[VmOp.cmpLt]!, (a, b) => _cmp(a, '<', _ctx.lt, b)),
      compareCase(n[VmOp.cmpLe]!, (a, b) => _cmp(a, '<=', _ctx.le, b)),
      compareCase(n[VmOp.cmpGt]!, (a, b) => _cmp(a, '>', _ctx.gt, b)),
      compareCase(n[VmOp.cmpGe]!, (a, b) => _cmp(a, '>=', _ctx.ge, b)),
      // dup: stack[sp] = stack[sp-1]; sp++;
      _case(
        n[VmOp.dup]!,
        Block([
          setStack(_ig(sp), stackAt(spMinus(1))),
          incSp(),
          brk(),
        ]),
      ),
      // jz: t = code[pc]; pc++; sp--; if (stack[sp] == 0) pc = t;
      _buildJzCase(code: code, stack: stack, sp: sp, pc: pc, brk: brk),
      // jmp: pc = code[pc];
      _case(
        n[VmOp.jmp]!,
        Block([
          _set(pc, _lget(code, _ig(pc))),
          brk(),
        ]),
      ),
      // ret: sp--; return stack[sp];
      _case(
        n[VmOp.ret]!,
        Block([
          decSp(),
          ReturnStatement(stackAt(_ig(sp))),
        ]),
      ),
    ];
  }

  SwitchCase _buildJzCase({
    required VariableDeclaration code,
    required VariableDeclaration stack,
    required VariableDeclaration sp,
    required VariableDeclaration pc,
    required Statement Function() brk,
  }) {
    final t = VariableDeclaration(
      't',
      type: _ctx.intType,
      initializer: _lget(code, _ig(pc)),
      isFinal: true,
    );
    return _case(
      kOpcodeNumbers[VmOp.jz]!,
      Block([
        t,
        _set(pc, _add1(_ig(pc))),
        _set(sp, _bin(_ig(sp), '-', _ctx.sub, IntLiteral(1))),
        IfStatement(
          _eq(_lget(stack, _ig(sp)), IntLiteral(0)),
          _set(pc, _ig(t)),
          null,
        ),
        brk(),
      ]),
    );
  }

  // ---- kernel node builders ----
  SwitchCase _case(int opcode, Statement body) => SwitchCase(
    [ConstantExpression(IntConstant(opcode), _ctx.intType)],
    [TreeNode.noOffset],
    body,
  );

  Expression _ig(VariableDeclaration v) => VariableGet(v);
  Statement _set(VariableDeclaration v, Expression e) =>
      ExpressionStatement(VariableSet(v, e));
  Expression _add1(Expression e) => _bin(e, '+', _ctx.add, IntLiteral(1));

  Expression _lget(VariableDeclaration list, Expression idx) =>
      InstanceInvocation(
        InstanceAccessKind.Instance,
        _ig(list),
        Name('[]'),
        Arguments([idx]),
        interfaceTarget: _ctx.listIndexGet,
        functionType: FunctionType(
          [_ctx.intType],
          _ctx.intType,
          Nullability.nonNullable,
        ),
      );

  Expression _lset(VariableDeclaration list, Expression idx, Expression val) =>
      InstanceInvocation(
        InstanceAccessKind.Instance,
        _ig(list),
        Name('[]='),
        Arguments([idx, val]),
        interfaceTarget: _ctx.listIndexSet,
        functionType: FunctionType(
          [_ctx.intType, _ctx.intType],
          const VoidType(),
          Nullability.nonNullable,
        ),
      );

  Statement _lsetStmt(
    VariableDeclaration list,
    Expression idx,
    Expression val,
  ) => ExpressionStatement(_lset(list, idx, val));

  Expression _bin(Expression a, String name, Procedure m, Expression b) =>
      InstanceInvocation(
        InstanceAccessKind.Instance,
        a,
        Name(name),
        Arguments([b]),
        interfaceTarget: m,
        functionType: FunctionType(
          [_ctx.intType],
          _ctx.intType,
          Nullability.nonNullable,
        ),
      );

  Expression _bitNot(Expression a) => InstanceInvocation(
    InstanceAccessKind.Instance,
    a,
    Name('~'),
    Arguments([]),
    interfaceTarget: _ctx.bitNot,
    functionType: FunctionType([], _ctx.intType, Nullability.nonNullable),
  );

  Expression _eq(Expression a, Expression b) => EqualsCall(
    a,
    b,
    functionType: FunctionType(
      [_ctx.objectType],
      _ctx.boolType,
      Nullability.nonNullable,
    ),
    interfaceTarget: _ctx.objectEquals,
  );

  Expression _cmp(Expression a, String name, Procedure m, Expression b) =>
      InstanceInvocation(
        InstanceAccessKind.Instance,
        a,
        Name(name),
        Arguments([b]),
        interfaceTarget: m,
        functionType: FunctionType(
          [_ctx.intType],
          _ctx.boolType,
          Nullability.nonNullable,
        ),
      );

  String _freshName() => '_vm\$${_counter++}';

  /// Builds the replacement body for a virtualized function:
  ///   `return _vm$N(const [<words>], [p0, p1, ...]);`  (int return), or
  ///   `return _vm$N(...) != 0;`                         (bool return).
  Statement buildReplacementBody({
    required Procedure interpreter,
    required List<int> words,
    required List<VariableDeclaration> params,
    required bool returnsBool,
  }) {
    // Post-modular-transforms kernel requires constants as ConstantExpression,
    // not an isConst ListLiteral, so build a ListConstant directly.
    final program = ConstantExpression(
      ListConstant(_ctx.intType, [for (final w in words) IntConstant(w)]),
      _ctx.listIntType,
    );
    final argsList = ListLiteral(
      [for (final p in params) VariableGet(p)],
      typeArgument: _ctx.intType,
    );
    final call = StaticInvocation(
      interpreter,
      Arguments([program, argsList]),
    );
    if (!returnsBool) {
      return ReturnStatement(call);
    }
    // call != 0
    return ReturnStatement(
      Not(
        EqualsCall(
          call,
          IntLiteral(0),
          functionType: FunctionType(
            [_ctx.objectType],
            _ctx.boolType,
            Nullability.nonNullable,
          ),
          interfaceTarget: _ctx.objectEquals,
        ),
      ),
    );
  }
}

final class _VmKernelContext {
  _VmKernelContext(Component component) {
    final core = component.libraries.firstWhere(
      (l) => l.importUri.toString() == 'dart:core',
    );
    final intClass = core.classes.firstWhere((c) => c.name == 'int');
    final numClass = core.classes.firstWhere((c) => c.name == 'num');
    final boolClass = core.classes.firstWhere((c) => c.name == 'bool');
    final objectClass = core.classes.firstWhere((c) => c.name == 'Object');
    final listClass = core.classes.firstWhere((c) => c.name == 'List');
    pragmaClass = core.classes.firstWhere((c) => c.name == 'pragma');
    pragmaNameField = pragmaClass.fields.firstWhere(
      (f) => f.name.text == 'name',
    );
    pragmaOptionsField = pragmaClass.fields.firstWhere(
      (f) => f.name.text == 'options',
    );

    intType = InterfaceType(intClass, Nullability.nonNullable);
    boolType = InterfaceType(boolClass, Nullability.nonNullable);
    objectType = InterfaceType(objectClass, Nullability.nonNullable);
    listIntType = InterfaceType(listClass, Nullability.nonNullable, [intType]);

    Procedure intOp(String n) =>
        intClass.procedures.firstWhere((p) => p.name.text == n);
    Procedure numOp(String n) =>
        numClass.procedures.firstWhere((p) => p.name.text == n);

    add = numOp('+');
    sub = numOp('-');
    mul = numOp('*');
    xor = intOp('^');
    and = intOp('&');
    or = intOp('|');
    shl = intOp('<<');
    shr = intOp('>>');
    bitNot = intOp('~');
    lt = numOp('<');
    le = numOp('<=');
    gt = numOp('>');
    ge = numOp('>=');
    objectEquals = objectClass.procedures.firstWhere(
      (p) => p.name.text == '==',
    );
    listFilled = listClass.procedures.firstWhere(
      (p) => p.name.text == 'filled' && p.isFactory,
    );
    listIndexGet = listClass.procedures.firstWhere((p) => p.name.text == '[]');
    listIndexSet = listClass.procedures.firstWhere((p) => p.name.text == '[]=');
  }

  late final InterfaceType intType;
  late final InterfaceType boolType;
  late final InterfaceType objectType;
  late final InterfaceType listIntType;
  late final Procedure add;
  late final Procedure sub;
  late final Procedure mul;
  late final Procedure xor;
  late final Procedure and;
  late final Procedure or;
  late final Procedure shl;
  late final Procedure shr;
  late final Procedure bitNot;
  late final Procedure lt;
  late final Procedure le;
  late final Procedure gt;
  late final Procedure ge;
  late final Procedure objectEquals;
  late final Procedure listFilled;
  late final Procedure listIndexGet;
  late final Procedure listIndexSet;
  late final Class pragmaClass;
  late final Field pragmaNameField;
  late final Field pragmaOptionsField;

  ConstantExpression neverInlineAnnotation() => ConstantExpression(
    InstanceConstant(
      pragmaClass.reference,
      const [],
      <Reference, Constant>{
        pragmaNameField.fieldReference: StringConstant('vm:never-inline'),
        pragmaOptionsField.fieldReference: NullConstant(),
      },
    ),
  );
}
