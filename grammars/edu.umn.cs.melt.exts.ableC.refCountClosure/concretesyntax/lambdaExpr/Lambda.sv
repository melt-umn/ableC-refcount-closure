grammar edu:umn:cs:melt:exts:ableC:refCountClosure:concretesyntax:lambdaExpr;

imports edu:umn:cs:melt:ableC:concretesyntax;
imports silver:langutil;

imports edu:umn:cs:melt:ableC:abstractsyntax:host;
imports edu:umn:cs:melt:ableC:abstractsyntax:construction;
imports edu:umn:cs:melt:ableC:abstractsyntax:env;
--imports edu:umn:cs:melt:ableC:abstractsyntax:debug;

import edu:umn:cs:melt:exts:ableC:refCountClosure:abstractsyntax;

marking terminal Lambda_t 'lambda' lexer classes {Ckeyword};

concrete productions top::PostfixExpr_c
| 'lambda' captured::MaybeCaptureList_c '(' params::ParameterList_c ')' '->' '(' res::Expr_c ')'
    { top.ast = refCountLambdaExpr(captured.ast, foldParameterDecl(params.ast), res.ast, location=top.location); }
| 'lambda' captured::MaybeCaptureList_c '(' ')' '->' '(' res::Expr_c ')'
    { top.ast = refCountLambdaExpr(captured.ast, nilParameters(), res.ast, location=top.location); }
| 'lambda' captured::MaybeCaptureList_c '(' params::ParameterList_c ')' '->' '(' res::TypeName_c ')' '{' body::BlockItemList_c '}'
    { top.ast = refCountLambdaStmtExpr(captured.ast, foldParameterDecl(params.ast), res.ast, foldStmt(body.ast), location=top.location); }
| 'lambda' captured::MaybeCaptureList_c '(' ')' '->' '(' res::TypeName_c ')' '{' body::BlockItemList_c '}'
    { top.ast = refCountLambdaStmtExpr(captured.ast, nilParameters(), res.ast, foldStmt(body.ast), location=top.location); }
| 'lambda' captured::MaybeCaptureList_c '(' params::ParameterList_c ')' '->' '(' res::TypeName_c ')' '{' '}'
    { top.ast = refCountLambdaStmtExpr(captured.ast, foldParameterDecl(params.ast), res.ast, nullStmt(), location=top.location); }
| 'lambda' captured::MaybeCaptureList_c '(' ')' '->' '(' res::TypeName_c ')' '{' '}'
    { top.ast = refCountLambdaStmtExpr(captured.ast, nilParameters(), res.ast, nullStmt(), location=top.location); }

nonterminal MaybeCaptureList_c with ast<MaybeCaptureList>;

concrete productions top::MaybeCaptureList_c
| '[' cl::CaptureList_c ']'
    { top.ast = justCaptureList(cl.ast); }
| 
    { top.ast = nothingCaptureList(); }

nonterminal CaptureList_c with ast<CaptureList>;

concrete productions top::CaptureList_c
| id::Identifier_t ',' rest::CaptureList_c
    { top.ast = consCaptureList(fromId(id), rest.ast); }
| id::Identifier_t
    { top.ast = consCaptureList(fromId(id), nilCaptureList()); }
|
    { top.ast = nilCaptureList(); }
