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
  local closureStructDecl::Decl = parseDecl(s"""
struct __attribute__((refId("${structRefId}"),
                      module("edu:umn:cs:melt:exts:ableC:refCountClosure:closure"))) ${structName} {
  const char *_fn_name; // For debugging
  void *_env; // Pointer to generated struct containing env
  __res_type__ (*_fn)(void *env, __params__); // First param is above env struct pointer
  refcount_tag_t _rt; // Reference counting for env
};
""");
  
  local localErrors::[Message] =
    checkRefCountInclude(loc, top.env) ++
    params.errors ++ res.errors;
  local fwrd::BaseTypeExpr =
    injectGlobalDeclsTypeExpr(
      consDecl(
        maybeRefIdDecl(
          structRefId,
          substDecl(
            [parametersSubstitution("__params__", params),
             typedefSubstitution("__res_type__", typeModifierTypeExpr(res.bty, res.mty))],
            closureStructDecl)),
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
  
  top.withoutTypeQualifiers = refCountClosureType(nilQualifier(), params, res);
  top.withoutExtensionQualifiers = refCountClosureType(filterExtensionQualifiers(q), params, res);
  top.withTypeQualifiers =
    refCountClosureType(foldQualifier(top.addedTypeQualifiers ++ q.qualifiers), params, res);
  top.mergeQualifiers = \t2::Type ->
    case t2 of
      refCountClosureType(q2, params2, res2) ->
        refCountClosureType(
          unionQualifiers(top.qualifiers, q2.qualifiers),
          zipWith(\ t1::Type t2::Type -> t1.mergeQualifiers(t2), params, params2),
          res.mergeQualifiers(res2))
    | _ -> forward.mergeQualifiers(t2)
    end;
  
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
