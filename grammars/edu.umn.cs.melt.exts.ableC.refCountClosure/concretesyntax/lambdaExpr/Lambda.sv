grammar edu:umn:cs:melt:exts:ableC:refCountClosure:concretesyntax:lambdaExpr;

imports edu:umn:cs:melt:ableC:concretesyntax;
imports silver:langutil;

imports edu:umn:cs:melt:ableC:abstractsyntax:host;
imports edu:umn:cs:melt:ableC:abstractsyntax:construction;
imports edu:umn:cs:melt:ableC:abstractsyntax:env;
--imports edu:umn:cs:melt:ableC:abstractsyntax:debug;

import edu:umn:cs:melt:exts:ableC:refCountClosure:abstractsyntax;

marking terminal Lambda_t 'lambda' lexer classes {Keyword, Global};

concrete productions top::PostfixExpr_c
| 'lambda' captured::MaybeCaptureList_c '(' params::ParameterList_c ')' '->' '(' res::Expr_c ')'
    { top.ast = refCountLambdaExpr(captured.ast, foldParameterDecl(params.ast), res.ast); }
| 'lambda' captured::MaybeCaptureList_c '(' ')' '->' '(' res::Expr_c ')'
    { top.ast = refCountLambdaExpr(captured.ast, nilParameters(), res.ast); }
| 'lambda' captured::MaybeCaptureList_c '(' params::ParameterList_c ')' '->' '(' res::TypeName_c ')' '{' body::BlockItemList_c '}'
    { top.ast = refCountLambdaStmtExpr(captured.ast, foldParameterDecl(params.ast), res.ast, foldStmt(body.ast)); }
| 'lambda' captured::MaybeCaptureList_c '(' ')' '->' '(' res::TypeName_c ')' '{' body::BlockItemList_c '}'
    { top.ast = refCountLambdaStmtExpr(captured.ast, nilParameters(), res.ast, foldStmt(body.ast)); }
| 'lambda' captured::MaybeCaptureList_c '(' params::ParameterList_c ')' '->' '(' res::TypeName_c ')' '{' '}'
    { top.ast = refCountLambdaStmtExpr(captured.ast, foldParameterDecl(params.ast), res.ast, nullStmt()); }
| 'lambda' captured::MaybeCaptureList_c '(' ')' '->' '(' res::TypeName_c ')' '{' '}'
    { top.ast = refCountLambdaStmtExpr(captured.ast, nilParameters(), res.ast, nullStmt()); }

tracked nonterminal MaybeCaptureList_c with ast<CaptureList>;

concrete productions top::MaybeCaptureList_c
| '[' cl::CaptureList_c ']'
    { top.ast = cl.ast; }
| 
    { top.ast = freeVariablesCaptureList(); }

tracked nonterminal CaptureList_c with ast<CaptureList>;

concrete productions top::CaptureList_c
| id::Identifier_c ',' rest::CaptureList_c
    { top.ast = consCaptureList(id.ast, rest.ast); }
| id::Identifier_c
    { top.ast = consCaptureList(id.ast, nilCaptureList()); }
| '...'
    { top.ast = freeVariablesCaptureList(); }
|
    { top.ast = nilCaptureList(); }
