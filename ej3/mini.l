%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mini.tab.h"
%}

%option noyywrap yylineno
DIG [0-9]
ID  [A-Za-z_][A-Za-z0-9_]*

%%
[ \t\r\n]+                 { /* ignorar espacios y saltos de linea */ }
"//".*                     { /* comentario de una linea */ }
"var"                      { return VAR;   }
"if"                       { return IF;    }
"else"                     { return ELSE;  }
"while"                    { return WHILE; }
"print"                    { return PRINT; }
"true"                     { return TRUE;  }
"false"                    { return FALSE; }
"&&"                       { return AND;   }
"||"                       { return OR;    }
"=="                       { return EQ;    }
"!="                       { return NE;    }
"<="                       { return LE;    }
">="                       { return GE;    }
"!"                        { return NOT;   }
{DIG}+(\.{DIG}+)?          { yylval.val = atof(yytext); return NUM; }
{ID}                       { yylval.id = strdup(yytext); return ID; }
[-+*/=<>(){};]             { return yytext[0]; }
.                          { fprintf(stderr, "Error lexico (linea %d): caracter no valido '%s'\n",
                                     yylineno, yytext); }
%%
