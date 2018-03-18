grammar edu:umn:cs:melt:exts:ableC:refCountClosure:abstractsyntax;
  
aspect function ovrld:getCallOverloadProd
Maybe<(Expr ::= Expr Exprs Location)> ::= t::Type env::Decorated Env
{
  overloads <- [pair("edu:umn:cs:melt:exts:ableC:refCountClosure:closure", refCountApplyExpr(_, _, location=_))];
}

abstract production refCountApplyExpr
top::Expr ::= fn::Expr args::Exprs
{
  propagate substituted;
  top.pp = parens(ppConcat([fn.pp, parens(ppImplode(cat(comma(), space()), args.pps))]));
  
  local localErrors::[Message] = checkIncludeErrors(top.location, top.env);
  local fwrd::Expr =
    applyTransExpr(fn, args, refCountClosureTypeExpr(_, _, _, builtin), isRefCountClosureType, location=top.location);
  
  forwards to mkErrorCheck(localErrors, fwrd);
}
