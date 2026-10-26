%{
#include <stdio.h>
#include <stdlib.h>
#include "units.h"
#include "conv.tab.h"
%}

%option noyywrap
DIG [0-9]

%%
[ \t\r]+                   { /* ignorar espacios */ }
{DIG}+(\.{DIG}+)?|\.{DIG}+ { yylval.val = atof(yytext); return NUM; }
"to"                       { return TO; }
[A-Za-z]+                  { const Unidad *u = buscar_unidad(yytext);
                             if (u == NULL) {
                                 fprintf(stderr, "Error lexico: unidad desconocida '%s'\n", yytext);
                                 return UNKNOWN;
                             }
                             yylval.u = u;
                             return UNIT; }
"-"                        { return '-'; }
\n                         { return EOL; }
.                          { fprintf(stderr, "Error lexico: caracter no valido '%s'\n", yytext);
                             return UNKNOWN; }
%%
