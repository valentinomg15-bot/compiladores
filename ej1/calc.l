%{
#include <stdio.h>
#include <stdlib.h>
#include "calc.tab.h"
%}

%option noyywrap
DIG [0-9]

%%
[ \t\r]+                                   { /* ignorar espacios */ }
{DIG}+(\.{DIG}*)?([eE][-+]?{DIG}+)?|\.{DIG}+ { yylval.val = atof(yytext); return NUM; }
"sin"                                      { return SIN;   }
"cos"                                      { return COS;   }
"tan"                                      { return TAN;   }
"asin"                                     { return ASIN;  }
"acos"                                     { return ACOS;  }
"atan"                                     { return ATAN;  }
"sqrt"                                     { return SQRT;  }
"todeg"                                    { return TODEG; }
"pi"                                       { return PI;    }
"deg"                                      { return DEG;   }
\n                                         { return EOL;   }
[-+*/^()]                                  { return yytext[0]; }
.                                          { fprintf(stderr, "Error lexico: caracter no valido '%s'\n", yytext); }
%%
