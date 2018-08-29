grammar edu:umn:cs:melt:exts:ableC:refCountClosure:abstractsyntax;

abstract production callMemberRefCountClosure
top::Expr ::= lhs::Expr deref::Boolean rhs::Name a::Exprs
{
  propagate substituted;
  top.pp = parens(ppConcat([lhs.pp, text(if deref then "->" else "."), rhs.pp]));
  
  local paramTypes::[Type] = refCountClosureParamTypes(lhs.typerep);
  local resultType::Type = refCountClosureResultType(lhs.typerep);
  local structName::String = refCountClosureStructName(paramTypes, resultType);
  
  forwards to
    injectGlobalDeclsExpr(
      consDecl(
        refCountClosureStructDecl(
          argTypesToParameters(paramTypes),
          typeName(directTypeExpr(resultType), baseTypeExpr())),
        nilDecl()),
      case rhs.name, a of
        "add_ref", nilExpr() -> ableC_Expr { add_ref(((struct $name{structName})$Expr{lhs}).rt) }
      | "add_ref", _ ->
          errorExpr([err(rhs.location, "Reference-counting closure reference addition expected no parameters")], location=builtin)
      | "remove_ref", nilExpr() -> ableC_Expr { remove_ref(((struct $name{structName})$Expr{lhs}).rt) }
      | "remove_ref", _ ->
          errorExpr([err(rhs.location, "Reference-counting closure reference removal expected no parameters")], location=builtin)
      | n, _ ->
          errorExpr([err(rhs.location, s"Reference-counting closure does not have field ${n}")], location=builtin)
      end,
      location=builtin);
}
