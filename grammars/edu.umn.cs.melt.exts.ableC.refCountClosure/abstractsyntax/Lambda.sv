grammar edu:umn:cs:melt:exts:ableC:refCountClosure:abstractsyntax;

imports silver:langutil;
imports silver:langutil:pp;

imports edu:umn:cs:melt:ableC:abstractsyntax:host;
imports edu:umn:cs:melt:ableC:abstractsyntax:construction;
imports edu:umn:cs:melt:ableC:abstractsyntax:env;
imports edu:umn:cs:melt:ableC:abstractsyntax:overloadable as ovrld;
imports silver:util:treemap as tm;
--imports edu:umn:cs:melt:ableC:abstractsyntax:debug;

exports edu:umn:cs:melt:exts:ableC:closure:abstractsyntax;

abstract production refCountLambdaExpr
top::Expr ::= captured::CaptureList params::Parameters res::Expr
{
  top.pp = pp"refcount::lambda [${captured.pp}](${ppImplode(text(", "), params.pps)}) -> (${res.pp})";
  
  local localErrors::[Message] =
    captured.errors ++ params.errors ++ res.errors ++
    checkRefCountInclude(top.env);
  
  local paramNames::[Name] =
    map(name, map(fst, foldr(append, [], map((.valueContribs), params.functionDefs))));
  captured.freeVariablesIn = removeAll(paramNames, nub(res.freeVariables));
  
  captured.env = top.env;
  params.env = openScopeEnv(top.env);
  params.controlStmtContext = top.controlStmtContext;
  params.position = 0;
  res.env = addEnv(params.defs ++ params.functionDefs, params.env);
  res.controlStmtContext = controlStmtContext(just(res.typerep), false, false, tm:empty());
  
  local fwrd::Expr =
    lambdaTransExpr(
      refCountMalloc(_, captured, captured.freeVariablesIn),
      captured, params, res, 
      refCountClosureType, refCountClosureStructDecl, refCountClosureStructName,
      refCountExtraInit1(captured, captured.freeVariablesIn), refCountExtraInit2);
  
  forwards to mkErrorCheck(localErrors, fwrd);
}

abstract production refCountLambdaStmtExpr
top::Expr ::= captured::CaptureList params::Parameters res::TypeName body::Stmt
{
  top.pp = pp"refcount::lambda [${captured.pp}](${ppImplode(text(", "), params.pps)}) -> (${res.pp}) ${braces(nestlines(2, body.pp))}";
  
  local localErrors::[Message] =
    captured.errors ++ params.errors ++ res.errors ++ body.errors ++
    checkRefCountInclude(top.env);
  
  local paramNames::[Name] =
    map(name, map(fst, foldr(append, [], map((.valueContribs), params.functionDefs))));
  captured.freeVariablesIn = removeAll(paramNames, nub(body.freeVariables));
  
  captured.env = top.env;
  params.env = openScopeEnv(addEnv(res.defs, res.env));
  params.controlStmtContext = top.controlStmtContext;
  params.position = 0;
  res.env = top.env;
  res.controlStmtContext = initialControlStmtContext;
  body.env = addEnv(params.defs ++ params.functionDefs, params.env);
  body.controlStmtContext = controlStmtContext(just(res.typerep), false, false, tm:add(body.labelDefs, tm:empty()));
  
  local fwrd::Expr =
    lambdaStmtTransExpr(
      refCountMalloc(_, captured, captured.freeVariablesIn),
      captured, params, res, body,
      refCountClosureType, refCountClosureStructDecl, refCountClosureStructName,
      refCountExtraInit1(captured, captured.freeVariablesIn), refCountExtraInit2);
  
  forwards to mkErrorCheck(localErrors, fwrd);
}

abstract production refCountExtraInit1
top::Stmt ::= captured::CaptureList freeVariables::[Name]
{
  top.pp = pp"refCountExtraInit1 [${captured.pp}];";
  attachNote extensionGenerated("ableC-refcount-closure");
  top.functionDefs := [];
  top.labelDefs := [];
  propagate env;
  captured.freeVariablesIn = freeVariables;
  
  forwards to
    ableC_Stmt {
      proto_typedef refcount_tag_t;
      refcount_tag_t _rt;
      $Stmt{
        if captured.numRefs > 0
        then ableC_Stmt { refcount_tag_t _refs[] = $Initializer{objectInitializer(captured.refsInitTrans)}; }
        else nullStmt()}
    };
}

abstract production refCountMalloc
top::Expr ::= size::Expr captured::CaptureList freeVariables::[Name]
{
  top.pp = pp"refCountMalloc [${captured.pp}](${size.pp})";
  attachNote extensionGenerated("ableC-refcount-closure");
  propagate env;
  captured.freeVariablesIn = freeVariables;
  
  forwards to
    if captured.numRefs > 0
    then ableC_Expr {
      refcount_refs_malloc($Expr{size}, &_rt, $intLiteralExpr{captured.numRefs}, _refs)
    }
    else ableC_Expr {
      refcount_malloc($Expr{size}, &_rt)
    };
}

global refCountExtraInit2::Stmt = ableC_Stmt { _result.rt = _rt; };-- fprintf(stderr, "Allocated %s\n", _result.fn_name); _rt->name = _result.fn_name;

synthesized attribute numRefs::Integer occurs on CaptureList;
synthesized attribute refsInitTrans::InitList occurs on CaptureList;

aspect production consCaptureList
top::CaptureList ::= h::Name t::CaptureList
{
  attachNote extensionGenerated("ableC-refcount-closure");
  local isRefCountTag::Boolean =
    case h.valueItem.typerep of
      pointerType(
        _,
        extType(nilQualifier(), refIdExtType(structSEU(), just("refcount_tag_s"), _))) -> true
    | _ -> false
    end;
  local isRefCountClosure::Boolean = isRefCountClosureType(h.valueItem.typerep);
  local paramTypes::[Type] = refCountClosureParamTypes(h.valueItem.typerep);
  local resultType::Type = refCountClosureResultType(h.valueItem.typerep);
  local structName::String = refCountClosureStructName(paramTypes, resultType);
  top.numRefs = t.numRefs + toInteger(isRefCountTag || isRefCountClosure);
  top.refsInitTrans =
    if isRefCountTag
    then
      consInit(
        positionalInit(exprInitializer(declRefExpr(h))),
        t.refsInitTrans)
    else if isRefCountClosure
    then
      consInit(
        positionalInit(exprInitializer(ableC_Expr { ((struct $name{structName})$Name{h}).rt })),
        t.refsInitTrans)
    else t.refsInitTrans;
}

aspect production nilCaptureList
top::CaptureList ::= 
{
  top.numRefs = 0;
  top.refsInitTrans = nilInit();
}

function checkRefCountInclude
[Message] ::= env::Decorated Env
{
  return
    if !null(lookupTag("refcount_tag_s", env)) then []
    else [errFromOrigin(ambientOrigin(), "Reference-counting closures require <refcount.h> to be included.")];
}
