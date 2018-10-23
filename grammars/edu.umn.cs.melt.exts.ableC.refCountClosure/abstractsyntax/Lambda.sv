grammar edu:umn:cs:melt:exts:ableC:refCountClosure:abstractsyntax;

imports silver:langutil;
imports silver:langutil:pp;

imports edu:umn:cs:melt:ableC:abstractsyntax:host;
imports edu:umn:cs:melt:ableC:abstractsyntax:construction;
imports edu:umn:cs:melt:ableC:abstractsyntax:construction:parsing;
imports edu:umn:cs:melt:ableC:abstractsyntax:substitution;
imports edu:umn:cs:melt:ableC:abstractsyntax:env;
imports edu:umn:cs:melt:ableC:abstractsyntax:overloadable as ovrld;
--imports edu:umn:cs:melt:ableC:abstractsyntax:debug;

exports edu:umn:cs:melt:exts:ableC:closure:abstractsyntax;

global builtin::Location = builtinLoc("refCountClosure");

abstract production refCountLambdaExpr
top::Expr ::= captured::CaptureList params::Parameters res::Expr
{
  propagate substituted;
  top.pp = pp"refcount::lambda [${captured.pp}](${ppImplode(text(", "), params.pps)}) -> (${res.pp})";
  
  local localErrors::[Message] =
    captured.errors ++ params.errors ++ res.errors ++
    checkRefCountInclude(top.location, top.env);
  
  local paramNames::[Name] =
    map(name(_, location=builtin), map(fst, foldr(append, [], map((.valueContribs), params.functionDefs))));
  captured.freeVariablesIn = removeAllBy(nameEq, paramNames, nubBy(nameEq, res.freeVariables));
  
  params.env = openScopeEnv(top.env);
  params.position = 0;
  res.env = addEnv(params.defs ++ params.functionDefs, params.env);
  res.returnType = just(res.typerep);
  
  local fwrd::Expr =
    lambdaTransExpr(
      refCountMalloc(_, captured, captured.freeVariablesIn, location=_),
      captured, params, res, 
      refCountClosureType, refCountClosureStructDecl, refCountClosureStructName,
      refCountExtraInit1(captured, captured.freeVariablesIn), refCountExtraInit2,
      location=top.location);
  
  forwards to mkErrorCheck(localErrors, fwrd);
}

abstract production refCountLambdaStmtExpr
top::Expr ::= captured::CaptureList params::Parameters res::TypeName body::Stmt
{
  propagate substituted;
  top.pp = pp"refcount::lambda [${captured.pp}](${ppImplode(text(", "), params.pps)}) -> (${res.pp}) ${braces(nestlines(2, body.pp))}";
  
  local localErrors::[Message] =
    captured.errors ++ params.errors ++ res.errors ++ body.errors ++
    checkRefCountInclude(top.location, top.env);
  
  local paramNames::[Name] =
    map(name(_, location=builtin), map(fst, foldr(append, [], map((.valueContribs), params.functionDefs))));
  captured.freeVariablesIn = removeAllBy(nameEq, paramNames, nubBy(nameEq, body.freeVariables));
  
  params.env = openScopeEnv(addEnv(res.defs, res.env));
  params.position = 0;
  res.env = top.env;
  res.returnType = nothing();
  body.env = addEnv(params.defs ++ params.functionDefs, params.env);
  body.returnType = just(res.typerep);
  
  local fwrd::Expr =
    lambdaStmtTransExpr(
      refCountMalloc(_, captured, captured.freeVariablesIn, location=_),
      captured, params, res, body,
      refCountClosureType, refCountClosureStructDecl, refCountClosureStructName,
      refCountExtraInit1(captured, captured.freeVariablesIn), refCountExtraInit2,
      location=top.location);
  
  forwards to mkErrorCheck(localErrors, fwrd);
}

abstract production refCountExtraInit1
top::Stmt ::= captured::CaptureList freeVariables::[Name]
{
  propagate substituted;
  top.pp = pp"refCountExtraInit1 [${captured.pp}];";
  top.functionDefs := [];
  captured.freeVariablesIn = freeVariables;
  
  forwards to
    ableC_Stmt {
      proto_typedef refcount_tag_t;
      refcount_tag_t _rt;
      refcount_tag_t _refs[] = $Initializer{objectInitializer(captured.refsInitTrans)};
    };
}

abstract production refCountMalloc
top::Expr ::= size::Expr captured::CaptureList freeVariables::[Name]
{
  propagate substituted;
  top.pp = pp"refCountMalloc [${captured.pp}](${size.pp})";
  captured.freeVariablesIn = freeVariables;
  
  forwards to
    ableC_Expr {
      refcount_refs_malloc($Expr{size}, &_rt, $intLiteralExpr{captured.numRefs}, _refs)
    };
}

global refCountExtraInit2::Stmt = ableC_Stmt { _result.rt = _rt; };-- fprintf(stderr, "Allocated %s\n", _result.fn_name); _rt->name = _result.fn_name;

synthesized attribute numRefs::Integer occurs on CaptureList;
synthesized attribute refsInitTrans::InitList occurs on CaptureList;

aspect production consCaptureList
top::CaptureList ::= h::Name t::CaptureList
{
  local isRefCountTag::Boolean =
    case h.valueItem.typerep of
      pointerType(
        _,
        extType(nilQualifier(), refIdExtType(structSEU(), "refcount_tag_s", _))) -> true
    | _ -> false
    end;
  local isRefCountClosure::Boolean = isRefCountClosureType(h.valueItem.typerep);
  local paramTypes::[Type] = refCountClosureParamTypes(h.valueItem.typerep);
  local resultType::Type = refCountClosureResultType(h.valueItem.typerep);
  local structName::String = refCountClosureStructName(paramTypes, resultType);
  top.numRefs = t.numRefs + toInt(isRefCountTag || isRefCountClosure);
  top.refsInitTrans =
    if isRefCountTag
    then
      consInit(
        positionalInit(exprInitializer(declRefExpr(h, location=builtin))),
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
[Message] ::= loc::Location env::Decorated Env
{
  return
    if !null(lookupTag("refcount_tag_s", env)) then []
    else [err(loc, "Reference-counting closures require <refcount.h> to be included.")];
}
