grammar edu:umn:cs:melt:exts:ableC:refCountClosure:abstractsyntax;

import edu:umn:cs:melt:ableC:abstractsyntax:overloadable;

abstract production refCountClosureTypeExpr
top::BaseTypeExpr ::= q::Qualifiers params::Parameters res::TypeName loc::Location
{
  top.pp = pp"${terminate(space(), q.pps)}refcount::closure<(${
    if null(params.pps) then pp"void" else ppImplode(pp", ", params.pps)}) -> ${res.pp}>";
  
  params.position = 0;
  res.env = addEnv(params.defs, top.env);
  
  local structName::String = refCountClosureStructName(params.typereps, res.typerep);
  local structRefId::String = s"edu:umn:cs:melt:exts:ableC:refCountClosure:${structName}";
  
  local localErrors::[Message] =
    checkRefCountInclude(loc, top.env) ++
    params.errors ++ res.errors;
  local fwrd::BaseTypeExpr =
    injectGlobalDeclsTypeExpr(
      consDecl(refCountClosureStructDecl(params, res), nilDecl()),
      extTypeExpr(q, refCountClosureType(params.typereps, res.typerep)));
  
  forwards to if !null(localErrors) then errorTypeExpr(localErrors) else fwrd;
}

abstract production refCountClosureStructDecl
top::Decl ::= params::Parameters res::TypeName
{
  top.pp = pp"refCountClosureStructDecl<(${
    if null(params.pps) then pp"void" else ppImplode(pp", ", params.pps)}) -> ${res.pp}>;";
  
  params.position = 0;
  
  local structName::String = refCountClosureStructName(params.typereps, res.typerep);
  local structRefId::String = s"edu:umn:cs:melt:exts:ableC:refCountClosure:${structName}";
  
  forwards to
    maybeRefIdDecl(
      structRefId,
      ableC_Decl {
        proto_typedef refcount_tag_t;
        struct __attribute__((refId($stringLiteralExpr{structRefId}))) $name{structName} {
          const char *fn_name; // For debugging
          void *env; // Pointer to generated struct containing env
          // Implementation function pointer
          // First param is above env struct pointer
          // Remaining params are params of the closure
          $BaseTypeExpr{typeModifierTypeExpr(res.bty, res.mty)} (*fn)(void *env, $Parameters{params});
          refcount_tag_t rt; // Reference counting for env
        };
      });
}

abstract production refCountClosureType
top::ExtType ::= params::[Type] res::Type
{
  propagate canonicalType;
  
  top.pp = pp"refcount::closure<(${
    if null(params) then pp"void" else
      ppImplode(
        pp", ",
        zipWith(cat,
          map((.lpp), params),
          map((.rpp), params)))}) -> ${res.lpp}${res.rpp}>";
  
  local structName::String = refCountClosureStructName(params, res);
  local structRefId::String = s"edu:umn:cs:melt:exts:ableC:refCountClosure:${structName}";
  local isErrorType::Boolean =
    any(map(\ t::Type -> case t of errorType() -> true | _ -> false end, res :: params));
  
  top.host =
    if isErrorType
    then errorType()
    else extType(top.givenQualifiers, refIdExtType(structSEU(), just(structName), structRefId));
  top.mangledName = s"_refcount_closure_${implode("_", map((.mangledName), params))}_${res.mangledName}";
  top.isEqualTo =
    \ other::ExtType ->
      case other of
        refCountClosureType(otherParams, otherRes) ->
          length(params) == length(otherParams) &&
          all(zipWith(compatibleTypes(_, _, false, false), res :: params, otherRes :: otherParams))
      | _ -> false
      end;
  
  top.callProd = just(refCountApplyExpr(_, _, location=_));
  top.callMemberProd = just(callMemberRefCountClosure(_, _, _, _, location=_));
}

function refCountClosureStructName
String ::= params::[Type] res::Type
{
  return refCountClosureType(params, res).mangledName ++ "_s";
}

-- Check if a type is a refcount closure
function isRefCountClosureType
Boolean ::= t::Type
{
  return
    case t of
      extType(_, refCountClosureType(_, _)) -> true
    | _ -> false
    end;
}

-- Find the parameter types of a refcount closure type
function refCountClosureParamTypes
[Type] ::= t::Type
{
  return
    case t of
      extType(_, refCountClosureType(paramTypes, _)) -> paramTypes
    | _ -> []
    end;
}

-- Find the result type of a refcount closure type
function refCountClosureResultType
Type ::= t::Type
{
  return
    case t of
      extType(_, refCountClosureType(_, resType)) -> resType
    | _ -> errorType()
    end;
}
