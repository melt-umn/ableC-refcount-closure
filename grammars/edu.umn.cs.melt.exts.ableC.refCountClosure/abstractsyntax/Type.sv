grammar edu:umn:cs:melt:exts:ableC:refCountClosure:abstractsyntax;

abstract production refCountClosureTypeExpr
top::BaseTypeExpr ::= q::Qualifiers params::Parameters res::TypeName loc::Location
{
  propagate substituted;
  top.pp = pp"${terminate(space(), q.pps)}refcount::closure<(${
    if null(params.pps) then pp"void" else ppImplode(pp", ", params.pps)}) -> ${res.pp}>";
  
  res.env = addEnv(params.defs, top.env);
  
  local structName::String = refCountClosureStructName(params.typereps, res.typerep);
  local structRefId::String = s"edu:umn:cs:melt:exts:ableC:refCountClosure:${structName}";
  
  local localErrors::[Message] =
    checkRefCountInclude(loc, top.env) ++
    params.errors ++ res.errors;
  local fwrd::BaseTypeExpr =
    injectGlobalDeclsTypeExpr(
      consDecl(
        maybeRefIdDecl(
          structRefId,
          ableC_Decl {
            struct __attribute__((refId($stringLiteralExpr{structRefId}),
                                  module("edu:umn:cs:melt:exts:ableC:refCountClosure:closure"))) $name{structName} {
              const char *_fn_name; // For debugging
              void *_env; // Pointer to generated struct containing env
              $BaseTypeExpr{typeModifierTypeExpr(res.bty, res.mty)} (*_fn)(void *env, $Parameters{params}); // First param is above env struct pointer
              refcount_tag_t _rt; // Reference counting for env
            };
          }),
        nilDecl()),
      directTypeExpr(refCountClosureType(q, params.typereps, res.typerep)));
  
  forwards to if !null(localErrors) then errorTypeExpr(localErrors) else fwrd;
}

abstract production refCountClosureType
top::Type ::= q::Qualifiers params::[Type] res::Type
{
  propagate substituted;
  
  top.lpp = pp"${terminate(space(), q.pps)}refcount::closure<(${
    if null(params) then pp"void" else
      ppImplode(
        pp", ",
        zipWith(cat,
          map((.lpp), params),
          map((.rpp), params)))}) -> ${res.lpp}${res.rpp}>";
  top.rpp = notext();
  
  top.withTypeQualifiers =
    refCountClosureType(foldQualifier(top.addedTypeQualifiers ++ q.qualifiers), params, res);
  
  local structName::String = refCountClosureStructName(params, res);
  local structRefId::String = s"edu:umn:cs:melt:exts:ableC:refCountClosure:${structName}";
  
  local isErrorType::Boolean =
    foldr(
      \ a::Boolean b::Boolean -> a || b, false,
      map(\ t::Type -> case t of errorType() -> true | _ -> false end, res :: params));
  
  forwards to
    if isErrorType
    then errorType()
    else tagType(q, refIdTagType(structSEU(), structName, structRefId));
}

function refCountClosureStructName
String ::= params::[Type] res::Type
{
  return s"_refcount_closure_${implode("_", map((.mangledName), params))}_${res.mangledName}_s";
}

-- Check if a type is a refrence-counting closure in a non-interfering way
function isRefCountClosureType
Boolean ::= t::Type
{
  return
    case t of
      tagType(_, refIdTagType(_, _, refId)) ->
        startsWith("edu:umn:cs:melt:exts:ableC:refCountClosure:", refId)
    | _ -> false
    end;
}
