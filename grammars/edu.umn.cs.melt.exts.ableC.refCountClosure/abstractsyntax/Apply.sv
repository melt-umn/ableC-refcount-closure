grammar edu:umn:cs:melt:exts:ableC:refCountClosure:abstractsyntax;

abstract production refCountApplyExpr
top::Expr ::= fn::Expr args::Exprs
{
  top.pp = parens(ppConcat([fn.pp, parens(ppImplode(cat(comma(), space()), args.pps))]));
  attachNote extensionGenerated("ableC-refcount-closure");
  propagate env, controlStmtContext;
  
  local localErrors :: [Message] =
    (if isRefCountClosureType(fn.typerep)
     then args.argumentErrors
     else [errFromOrigin(fn, s"Cannot apply non reference-counting closure (got ${showType(fn.typerep)})")]) ++
    fn.errors ++ args.errors;
  
  local paramTypes::[Type] = refCountClosureParamTypes(fn.typerep);
  local resultType::Type = refCountClosureResultType(fn.typerep);
  
  args.argumentPosition = 1;
  args.callExpr = fn;
  args.callVariadic = false;
  args.expectedTypes = paramTypes;
  
  local structName::String = refCountClosureStructName(paramTypes, resultType);
  local fwrd::Expr =
    injectGlobalDeclsExpr(
      consDecl(
        refCountClosureStructDecl(
          argTypesToParameters(paramTypes),
          typeName(directTypeExpr(resultType), baseTypeExpr())),
        nilDecl()),
      ableC_Expr {
        ({struct $name{structName} _tmp_closure = (struct $name{structName})$Expr{fn};
          _tmp_closure.fn(_tmp_closure.env, $Exprs{args});})
      });

  forwards to mkErrorCheck(localErrors, fwrd);
}