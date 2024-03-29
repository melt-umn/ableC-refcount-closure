grammar edu:umn:cs:melt:exts:ableC:refCountClosure:concretesyntax:typeExpr;

imports edu:umn:cs:melt:ableC:concretesyntax;
imports silver:langutil only ast;

imports edu:umn:cs:melt:ableC:abstractsyntax:host hiding givenQualifiers;
imports edu:umn:cs:melt:ableC:abstractsyntax:construction;
imports edu:umn:cs:melt:ableC:abstractsyntax:env;
--imports edu:umn:cs:melt:ableC:abstractsyntax:debug;

import edu:umn:cs:melt:exts:ableC:refCountClosure:abstractsyntax;

marking terminal Closure_t 'closure' lexer classes {Keyword, Global};

concrete productions top::TypeSpecifier_c
| 'closure' '<' te::RefCountClosureTypeExpr_c '>'
    { top.realTypeSpecifiers = [te.ast];
      top.preTypeSpecifiers = [];
      te.givenQualifiers = top.givenQualifiers; }

tracked nonterminal RefCountClosureTypeExpr_c with ast<BaseTypeExpr>, givenQualifiers;

concrete productions top::RefCountClosureTypeExpr_c
| '(' param::RefCountClosureTypeExpr_c ')' '->' ret::TypeName_c
    { top.ast = refCountClosureTypeExpr(top.givenQualifiers, consParameters(parameterDecl(nilStorageClass(), param.ast, baseTypeExpr(), nothingName(), nilAttribute()), nilParameters()), ret.ast);
      param.givenQualifiers = nilQualifier(); }
| '(' param::RefCountClosureTypeExpr_c ')' '->' rest::RefCountClosureTypeExpr_c
    { top.ast = refCountClosureTypeExpr(top.givenQualifiers, consParameters(parameterDecl(nilStorageClass(), param.ast, baseTypeExpr(), nothingName(), nilAttribute()), nilParameters()), typeName(rest.ast, baseTypeExpr()));
      param.givenQualifiers = nilQualifier();
      rest.givenQualifiers = nilQualifier(); }
| '(' params::ClosureParameterList_c ')' '->' rest::RefCountClosureTypeExpr_c
    { top.ast = refCountClosureTypeExpr(top.givenQualifiers, foldParameterDecl(params.ast), typeName(rest.ast, baseTypeExpr()));
      rest.givenQualifiers = nilQualifier(); }
| '(' params::ClosureParameterList_c ')' '->' ret::TypeName_c
    { top.ast = refCountClosureTypeExpr(top.givenQualifiers, foldParameterDecl(params.ast), ret.ast); }
| '(' ')' '->' rest::RefCountClosureTypeExpr_c
    { top.ast = refCountClosureTypeExpr(top.givenQualifiers, nilParameters(), typeName(rest.ast, baseTypeExpr()));
      rest.givenQualifiers = nilQualifier(); }
| '(' ')' '->' ret::TypeName_c
    { top.ast = refCountClosureTypeExpr(top.givenQualifiers, nilParameters(), ret.ast); }

-- Duplicate of ParameterList_c so MDA doesn't complain
closed tracked nonterminal ClosureParameterList_c with declaredIdents, ast<[ParameterDecl]>;
concrete productions top::ClosureParameterList_c
| h::ParameterDeclaration_c 
    { top.declaredIdents = h.declaredIdents;
      top.ast = [h.ast];
    }
| h::ClosureParameterList_c ',' t::ParameterDeclaration_c
    { top.declaredIdents = h.declaredIdents ++ t.declaredIdents;
      top.ast = h.ast ++ [t.ast];
    }
