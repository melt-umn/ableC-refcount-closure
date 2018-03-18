grammar edu:umn:cs:melt:exts:ableC:refCountClosure:abstractsyntax;

aspect function ovrld:getMemberCallOverloadProd
Maybe<(Expr ::= Expr Boolean Name Exprs Location)> ::= t::Type env::Decorated Env
{
  overloads <-
    [pair(
       "edu:umn:cs:melt:exts:ableC:refCountClosure:closure",
       memberCallRefCountClosure(_, _, _, _, location=_))];
}

abstract production memberCallRefCountClosure
top::Expr ::= lhs::Expr deref::Boolean rhs::Name a::Exprs
{
  propagate substituted;
  
  forwards to
    case rhs.name, a of
      "add_ref", nilExpr() ->
        directCallExpr(
          name("add_ref", location=builtin),
          consExpr(memberExpr(lhs, false, name("_rt", location=builtin), location=builtin), nilExpr()),
          location=builtin)
    | "add_ref", _ ->
        errorExpr([err(rhs.location, "Reference-counting closure reference addition expected no parameters")], location=builtin)
    | "remove_ref", nilExpr() ->
        directCallExpr(
          name("remove_ref", location=builtin),
          consExpr(memberExpr(lhs, false, name("_rt", location=builtin), location=builtin), nilExpr()),
          location=builtin)
    | "remove_ref", _ ->
        errorExpr([err(rhs.location, "Reference-counting closure reference removal expected no parameters")], location=builtin)
    | "_fn", _ -> callExpr(memberExpr(lhs, deref, rhs, location=top.location), a, location=builtin)
    | n, _ ->
        errorExpr([err(rhs.location, s"Reference-counting closure does not have field ${n}")], location=builtin)
    end;
}
