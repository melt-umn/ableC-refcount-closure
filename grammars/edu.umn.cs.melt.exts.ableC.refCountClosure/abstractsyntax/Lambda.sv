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
top::Expr ::= captured::MaybeCaptureList params::Parameters res::Expr
{
  propagate substituted;
  top.pp = pp"refcount_lambda ${captured.pp}(${ppImplode(text(", "), params.pps)}) -> (${res.pp})";
  
  local localErrors::[Message] =
    captured.errors ++ params.errors ++ res.errors ++
    checkIncludeErrors(top.location, top.env);
  
  local paramNames::[Name] =
    map(name(_, location=builtin), map(fst, foldr(append, [], map((.valueContribs), params.defs))));
  captured.freeVariablesIn = removeAllBy(nameEq, paramNames, nubBy(nameEq, res.freeVariables));
  
  res.env = openScopeEnv(addEnv(params.defs, params.env));
  res.returnType = just(res.typerep);
  
  local fwrd::Expr =
    lambdaTransExpr(
      refCountMalloc(_, captured, captured.freeVariablesIn, location=_),
      captured, params, res, 
      refCountClosureTypeExpr(_, _, _, builtin),
      refCountExtraInit1(captured, captured.freeVariablesIn), refCountExtraInit2,
      location=top.location);
  
  forwards to mkErrorCheck(localErrors, fwrd);
}

abstract production refCountLambdaStmtExpr
top::Expr ::= captured::MaybeCaptureList params::Parameters res::TypeName body::Stmt
{
  propagate substituted;
  top.pp = pp"refcount_lambda ${captured.pp}(${ppImplode(text(", "), params.pps)}) -> (${res.pp}) ${braces(nestlines(2, body.pp))}";
  
  local localErrors::[Message] =
    captured.errors ++ params.errors ++ res.errors ++ body.errors ++
    checkIncludeErrors(top.location, top.env);
  
  local paramNames::[Name] =
    map(name(_, location=builtin), map(fst, foldr(append, [], map((.valueContribs), params.defs))));
  captured.freeVariablesIn = removeAllBy(nameEq, paramNames, nubBy(nameEq, body.freeVariables));
  
  res.env = top.env;
  res.returnType = nothing();
  params.env = addEnv(res.defs, res.env);
  body.env = openScopeEnv(addEnv(params.defs, params.env));
  body.returnType = just(res.typerep);
  
  local fwrd::Expr =
    lambdaStmtTransExpr(
      refCountMalloc(_, captured, captured.freeVariablesIn, location=_),
      captured, params, res, body,
      refCountClosureTypeExpr(_, _, _, builtin),
      refCountExtraInit1(captured, captured.freeVariablesIn), refCountExtraInit2,
      location=top.location);
  
  forwards to mkErrorCheck(localErrors, fwrd);
}

abstract production refCountExtraInit1
top::Stmt ::= captured::MaybeCaptureList freeVariables::[Name]
{
  propagate substituted;
  top.pp = pp"refCountExtraInit1 ${captured.pp};";
  top.functionDefs := [];
  captured.freeVariablesIn = freeVariables;
  
  forwards to
    substStmt(
      [initializerSubstitution("__refs_init__", objectInitializer(captured.refsInitTrans))],
      parseStmt(s"""
proto_typedef refcount_tag;
refcount_tag _rt;
refcount_tag _refs[] = __refs_init__;
"""));
}

abstract production refCountMalloc
top::Expr ::= size::Expr captured::MaybeCaptureList freeVariables::[Name]
{
  propagate substituted;
  top.pp = pp"refCountMalloc ${captured.pp}(${size.pp})";
  captured.freeVariablesIn = freeVariables;
  
  forwards to
    substExpr(
      [declRefSubstitution("__size__", size)],
      parseExpr(
        s"refcount_malloc(__size__, &_rt, ${toString(captured.refCountClosureCount)}, _refs)"));
}

global refCountExtraInit2::Stmt = parseStmt("_result._rt = _rt;");--fprintf(stderr, \"Allocated %s\\n\", _result._fn_name); _rt->fn_name = _result._fn_name; 

synthesized attribute refCountClosureCount::Integer occurs on MaybeCaptureList, CaptureList;
synthesized attribute refsInitTrans::InitList occurs on MaybeCaptureList, CaptureList;

aspect production justCaptureList
top::MaybeCaptureList ::= cl::CaptureList
{
  top.refCountClosureCount = cl.refCountClosureCount;
  top.refsInitTrans = cl.refsInitTrans;
}

aspect production consCaptureList
top::CaptureList ::= h::Name t::CaptureList
{
  local isRefCountClosure::Boolean = isRefCountClosureType(h.valueItem.typerep);
  top.refCountClosureCount = t.refCountClosureCount + toInt(isRefCountClosure);
  top.refsInitTrans =
    if !isRefCountClosure then t.refsInitTrans else
      consInit(
        init(
          exprInitializer(
            memberExpr(
              declRefExpr(h, location=builtin),
              false,
              name("_rt", location=builtin),
              location=builtin))),
        t.refsInitTrans);
}

aspect production nilCaptureList
top::CaptureList ::= 
{
  top.refCountClosureCount = 0;
  top.refsInitTrans = nilInit();
}

function checkIncludeErrors
[Message] ::= loc::Location env::Decorated Env
{
  return
    if !null(lookupTag("refcount_tag_s", env)) then []
    else [err(loc, "Reference-counting closures require <refcount.h> to be included.")];
}
