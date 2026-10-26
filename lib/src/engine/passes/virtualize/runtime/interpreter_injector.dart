import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/isa.dart';
import 'package:refractor/src/engine/passes/virtualize/planning/vm_ir.dart';

/// Synthesizes a per-function switch-loop bytecode interpreter as kernel and
/// injects it as a top-level `@pragma('vm:never-inline')` static procedure.
///
/// Signature of the injected helper:
///   `int _vm$N(List<int> code, List<int> args)`
///
/// Opcode numbering and per-op semantics are specified canonically by `VmOp`
/// in `planning/vm_ir.dart`; this synthesized interpreter and the pure-Dart
/// `reference_interpreter.dart` are two mirrors of that spec and must stay
/// exactly equivalent (same opcode numbers, 64-bit int arithmetic, stack
/// discipline), so the E6 differential gate is sound. The per-function
/// [IsaProfile] supplies the opcode permutation and the position-keyed decode
/// baked into the synthesized loop.
final class InterpreterInjector {
  InterpreterInjector(Component component) : _ctx = _VmKernelContext(component);

  final _VmKernelContext _ctx;
  int _counter = 0;

  /// Injects an interpreter sized to [stackDepth] into [library], decoding and
  /// dispatching under [profile] (per-function opcode permutation + encoding).
  Procedure inject(Library library, int stackDepth, IsaProfile profile) {
    // Per-function keystream helper: int _ks$N(int pos) => <nonlinear mix>.
    final ks = _injectKeystreamHelper(library, profile);
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
      initializer: _decodedAt(code, pc, ks),
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
        profile: profile,
        ks: ks,
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
    final procedure =
        Procedure(
            Name(_freshName(library, '_vm'), library),
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
    required IsaProfile profile,
    required Procedure ks,
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

    // Binary op case: sp--; stack[sp-1] = MBA(stack[sp-1], stack[sp]);
    // Arithmetic/bitwise handlers are emitted as MBA identities (equal in value
    // to the plain op, so the reference oracle stays plain and E6 holds).
    SwitchCase binaryCase(VmOp op) {
      return _case(
        profile.opcode[op]!,
        Block([
          decSp(),
          setStack(
            spMinus(1),
            _mbaBinary(
              op,
              () => stackAt(spMinus(1)),
              () => stackAt(spMinus(0)),
            ),
          ),
          brk(),
        ]),
      );
    }

    // Superoperator case: c = decode(code[pc]); pc++;
    //                     stack[sp-1] = MBA(stack[sp-1], c);
    SwitchCase superopCase(VmOp op) {
      final base = baseOpForSuperop(op)!;
      final c = VariableDeclaration(
        'c',
        type: _ctx.intType,
        initializer: _decodedAt(code, pc, ks),
        isFinal: true,
      );
      return _case(
        profile.opcode[op]!,
        Block([
          c,
          incPc(),
          setStack(
            spMinus(1),
            _mbaBinary(base, () => stackAt(spMinus(1)), () => _ig(c)),
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

    final n = profile.opcode;
    return [
      // pushConst: stack[sp] = decode(code[pc]); pc++; sp++;
      _case(
        n[VmOp.pushConst]!,
        Block([
          setStack(_ig(sp), _decodedAt(code, pc, ks)),
          incPc(),
          incSp(),
          brk(),
        ]),
      ),
      // pushArg: stack[sp] = args[decode(code[pc])]; pc++; sp++;
      _case(
        n[VmOp.pushArg]!,
        Block([
          setStack(_ig(sp), _lget(args, _decodedAt(code, pc, ks))),
          incPc(),
          incSp(),
          brk(),
        ]),
      ),
      binaryCase(VmOp.add),
      binaryCase(VmOp.sub),
      binaryCase(VmOp.mul),
      binaryCase(VmOp.xor),
      binaryCase(VmOp.and),
      binaryCase(VmOp.or),
      binaryCase(VmOp.shl),
      binaryCase(VmOp.shr),
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
      // jz: t = decode(code[pc]); pc++; sp--; if (stack[sp] == 0) pc = t;
      _buildJzCase(
        code: code,
        stack: stack,
        sp: sp,
        pc: pc,
        brk: brk,
        profile: profile,
        ks: ks,
      ),
      // jmp: pc = decode(code[pc]);
      _case(
        n[VmOp.jmp]!,
        Block([
          _set(pc, _decodedAt(code, pc, ks)),
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
      // Superoperators (M2): fused `pushConst C; <binop>`.
      superopCase(VmOp.addImm),
      superopCase(VmOp.subImm),
      superopCase(VmOp.mulImm),
      superopCase(VmOp.xorImm),
      superopCase(VmOp.andImm),
      superopCase(VmOp.orImm),
      superopCase(VmOp.shlImm),
      superopCase(VmOp.shrImm),
      // Defensive trap: valid (assembler-produced) bytecode never reaches here,
      // but a default keeps a malformed opcode from spinning the loop forever.
      SwitchCase.defaultCase(
        ExpressionStatement(
          Throw(
            ConstantExpression(
              StringConstant('refractor: invalid opcode'),
              _ctx.stringType,
            ),
          ),
        ),
      ),
    ];
  }

  SwitchCase _buildJzCase({
    required VariableDeclaration code,
    required VariableDeclaration stack,
    required VariableDeclaration sp,
    required VariableDeclaration pc,
    required Statement Function() brk,
    required IsaProfile profile,
    required Procedure ks,
  }) {
    final t = VariableDeclaration(
      't',
      type: _ctx.intType,
      initializer: _decodedAt(code, pc, ks),
      isFinal: true,
    );
    return _case(
      profile.opcode[VmOp.jz]!,
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

  /// Builds `code[pc] ^ _ks(pc)` — the per-fetch decode, mirroring
  /// [IsaProfile.decode]. `pc` is read (not mutated) here.
  Expression _decodedAt(
    VariableDeclaration code,
    VariableDeclaration pc,
    Procedure ks,
  ) {
    final ksCall = StaticInvocation(ks, Arguments([_ig(pc)]));
    return _bin(_lget(code, _ig(pc)), '^', _ctx.xor, ksCall);
  }

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

  Expression _shl1(Expression e) => _bin(e, '<<', _ctx.shl, IntLiteral(1));

  /// Builds an MBA expression equal in value to `a OP b` for the hardened
  /// arithmetic/bitwise ops (identities verified in E4/E6); `mul`/`shl`/`shr`
  /// fall through to the plain op. `a`/`b` are thunks so each use gets a fresh
  /// node (kernel nodes can't be shared); they read the stack, which is
  /// unchanged while the handler's RHS is evaluated.
  Expression _mbaBinary(
    VmOp op,
    Expression Function() a,
    Expression Function() b,
  ) => switch (op) {
    // (a ^ b) + ((a & b) << 1)
    VmOp.add => _bin(
      _bin(a(), '^', _ctx.xor, b()),
      '+',
      _ctx.add,
      _shl1(_bin(a(), '&', _ctx.and, b())),
    ),
    // (a ^ b) - ((~a & b) << 1)
    VmOp.sub => _bin(
      _bin(a(), '^', _ctx.xor, b()),
      '-',
      _ctx.sub,
      _shl1(_bin(_bitNot(a()), '&', _ctx.and, b())),
    ),
    // (a | b) - (a & b)
    VmOp.xor => _bin(
      _bin(a(), '|', _ctx.or, b()),
      '-',
      _ctx.sub,
      _bin(a(), '&', _ctx.and, b()),
    ),
    // (a | b) - (a ^ b)
    VmOp.and => _bin(
      _bin(a(), '|', _ctx.or, b()),
      '-',
      _ctx.sub,
      _bin(a(), '^', _ctx.xor, b()),
    ),
    // (a & b) + (a ^ b)
    VmOp.or => _bin(
      _bin(a(), '&', _ctx.and, b()),
      '+',
      _ctx.add,
      _bin(a(), '^', _ctx.xor, b()),
    ),
    VmOp.mul => _bin(a(), '*', _ctx.mul, b()),
    VmOp.shl => _bin(a(), '<<', _ctx.shl, b()),
    VmOp.shr => _bin(a(), '>>', _ctx.shr, b()),
    _ => throw StateError('not a hardenable binary op: $op'),
  };

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

  String _freshName(Library library, String prefix) {
    final existing = library.procedures.map((p) => p.name.text).toSet();
    while (true) {
      final name = '$prefix\$${_counter++}';
      if (!existing.contains(name)) return name;
    }
  }

  /// Synthesizes `int _ks$N(int pos)` = the nonlinear position keystream
  /// (multiply + xorshift), mirroring [IsaProfile.keystream] exactly. Only the
  /// single per-function seed is baked; the multipliers are derived from it.
  Procedure _injectKeystreamHelper(Library library, IsaProfile profile) {
    final seed = profile.seed;
    final m1 = seed | 1;
    final m2 = (seed ^ kKsGolden) | 1;
    final pos = VariableDeclaration('pos', type: _ctx.intType);
    final h = VariableDeclaration(
      'h',
      type: _ctx.intType,
      initializer: _bin(_add1(_ig(pos)), '^', _ctx.xor, IntLiteral(seed)),
    );
    final body = Block([
      h,
      _set(h, _bin(_ig(h), '*', _ctx.mul, IntLiteral(m1))),
      _set(h, _bin(_ig(h), '^', _ctx.xor, _ushr(_ig(h), 29))),
      _set(h, _bin(_ig(h), '*', _ctx.mul, IntLiteral(m2))),
      _set(h, _bin(_ig(h), '^', _ctx.xor, _ushr(_ig(h), 32))),
      ReturnStatement(_bin(_ig(h), '&', _ctx.and, IntLiteral(kKeystreamMask))),
    ]);
    final fn = FunctionNode(
      body,
      positionalParameters: [pos],
      requiredParameterCount: 1,
      returnType: _ctx.intType,
    )..fileOffset = 0;
    final proc =
        Procedure(
            Name(_freshName(library, '_ks'), library),
            ProcedureKind.Method,
            fn,
            fileUri: library.fileUri,
            isStatic: true,
          )
          ..fileOffset = 0
          ..fileEndOffset = 0;
    library.addProcedure(proc);
    return proc;
  }

  Expression _ushr(Expression a, int n) =>
      _bin(a, '>>>', _ctx.ushr, IntLiteral(n));

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
    final stringClass = core.classes.firstWhere((c) => c.name == 'String');
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
    stringType = InterfaceType(stringClass, Nullability.nonNullable);
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
    ushr = intOp('>>>');
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
  late final InterfaceType stringType;
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
  late final Procedure ushr;
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
