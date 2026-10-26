%{
#include <stdio.h>
#include <math.h>

#define PI_VAL 3.14159265358979323846
#define EPS    1e-12

int  yylex(void);
void yyerror(const char *s);

static int error_sem = 0;   /* 1 si la linea actual tuvo un error semantico */

static void fallo(const char *msg) {
    fprintf(stderr, "Error semantico: %s\n", msg);
    error_sem = 1;
}
%}

%union { double val; }

%token <val> NUM
%token SIN COS TAN ASIN ACOS ATAN SQRT TODEG PI DEG EOL

%left  '+' '-'
%left  '*' '/'
%right UMINUS
%right '^'
%left  DEG

%type <val> expr

%%
entrada : /* vacio */
        | entrada linea
        ;

linea   : EOL
        | expr EOL   { if (!error_sem) {
                           double r = (fabs($1) < EPS) ? 0.0 : $1;
                           printf("= %.10g\n", r);
                       }
                       error_sem = 0; }
        | error EOL  { yyerrok; error_sem = 0; }
        ;

expr    : NUM                 { $$ = $1; }
        | PI                  { $$ = PI_VAL; }
        | expr '+' expr       { $$ = $1 + $3; }
        | expr '-' expr       { $$ = $1 - $3; }
        | expr '*' expr       { $$ = $1 * $3; }
        | expr '/' expr       { if ($3 == 0.0) { fallo("division entre cero"); $$ = 0; }
                                else $$ = $1 / $3; }
        | expr '^' expr       { $$ = pow($1, $3); }
        | '-' expr %prec UMINUS { $$ = -$2; }
        | '(' expr ')'        { $$ = $2; }
        | expr DEG            { $$ = $1 * PI_VAL / 180.0; }   /* grados -> radianes */
        | SIN  '(' expr ')'   { $$ = sin($3); }
        | COS  '(' expr ')'   { $$ = cos($3); }
        | TAN  '(' expr ')'   { if (fabs(cos($3)) < EPS) { fallo("tan(x) no esta definida (x = 90 grados + k*180)"); $$ = 0; }
                                else $$ = tan($3); }
        | ASIN '(' expr ')'   { if ($3 < -1.0 || $3 > 1.0) { fallo("asin(x) requiere -1 <= x <= 1"); $$ = 0; }
                                else $$ = asin($3); }
        | ACOS '(' expr ')'   { if ($3 < -1.0 || $3 > 1.0) { fallo("acos(x) requiere -1 <= x <= 1"); $$ = 0; }
                                else $$ = acos($3); }
        | ATAN '(' expr ')'   { $$ = atan($3); }
        | SQRT '(' expr ')'   { if ($3 < 0.0) { fallo("sqrt(x) requiere x >= 0"); $$ = 0; }
                                else $$ = sqrt($3); }
        | TODEG '(' expr ')'  { $$ = $3 * 180.0 / PI_VAL; }   /* radianes -> grados */
        ;
%%

void yyerror(const char *s) {
    fprintf(stderr, "Error sintactico: %s\n", s);
}

int main(void) {
    printf("Calculadora trigonometrica (Ctrl+D para salir)\n");
    return yyparse();
}
