%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

extern FILE *yyin;
extern int   yylineno;
int  yylex(void);
void yyerror(const char *s);

/* ---------- tipos del lenguaje y nodos del AST ---------- */
enum { T_NUM, T_BOOL };
enum { N_NUM, N_VAR, N_NEG, N_NOT, N_BIN, N_ASIGNA, N_PRINT, N_IF, N_WHILE };
enum { OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_LT, OP_GT, OP_LE, OP_GE,
       OP_EQ, OP_NE, OP_AND, OP_OR };

typedef struct Nodo {
    int    kind;              /* clase de nodo                          */
    int    op;                /* operador (nodos binarios)              */
    int    tipo;              /* ATRIBUTO SEMANTICO: T_NUM o T_BOOL     */
    int    idx;               /* indice en la tabla de simbolos         */
    double val;               /* valor de constantes                    */
    struct Nodo *a, *b, *c;   /* hijos                                  */
    struct Nodo *sig;         /* siguiente sentencia de una lista       */
} Nodo;

/* ---------- tabla de simbolos ---------- */
#define MAX_VARS 256
static struct { char nombre[64]; double valor; } tabla[MAX_VARS];
static int nvars = 0;

static int buscar_var(const char *n) {
    for (int i = 0; i < nvars; i++)
        if (strcmp(tabla[i].nombre, n) == 0) return i;
    return -1;
}
static int declarar_var(const char *n) {
    if (nvars >= MAX_VARS) { fprintf(stderr, "Demasiadas variables\n"); exit(1); }
    strncpy(tabla[nvars].nombre, n, 63);
    tabla[nvars].valor = 0;
    return nvars++;
}

/* ---------- errores semanticos ---------- */
static int errores_sem = 0;
static void error_sem(const char *fmt, ...) {
    va_list ap;
    fprintf(stderr, "Error semantico (linea %d): ", yylineno);
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fputc('\n', stderr);
    errores_sem++;
}

static const char *nombre_tipo(int t) { return t == T_NUM ? "numero" : "booleano"; }

/* ---------- constructores de nodos (aqui viven las comprobaciones de tipos) ---------- */
static Nodo *nuevo(int kind, int tipo) {
    Nodo *n = calloc(1, sizeof(Nodo));
    n->kind = kind; n->tipo = tipo;
    return n;
}
static Nodo *nodo_const(double v, int tipo) { Nodo *n = nuevo(N_NUM, tipo); n->val = v; return n; }
static Nodo *nodo_var(int idx)              { Nodo *n = nuevo(N_VAR, T_NUM); n->idx = idx; return n; }

static Nodo *nodo_bin(int op, Nodo *a, Nodo *b) {
    int req, res;
    switch (op) {
        case OP_ADD: case OP_SUB: case OP_MUL: case OP_DIV:
            req = T_NUM;  res = T_NUM;  break;
        case OP_LT: case OP_GT: case OP_LE: case OP_GE:
            req = T_NUM;  res = T_BOOL; break;
        case OP_AND: case OP_OR:
            req = T_BOOL; res = T_BOOL; break;
        default:                          /* == y !=: ambos del mismo tipo */
            req = a->tipo; res = T_BOOL; break;
    }
    if (a->tipo != req || b->tipo != req)
        error_sem("operandos incompatibles: se esperaba %s", nombre_tipo(req));
    if (op == OP_DIV && b->kind == N_NUM && b->tipo == T_NUM && b->val == 0)
        error_sem("division entre cero");
    Nodo *n = nuevo(N_BIN, res);
    n->op = op; n->a = a; n->b = b;
    return n;
}

static Nodo *nodo_un(int kind, Nodo *a) {
    int req = (kind == N_NEG) ? T_NUM : T_BOOL;
    if (a->tipo != req)
        error_sem("el operador unario requiere un %s", nombre_tipo(req));
    Nodo *n = nuevo(kind, req);
    n->a = a;
    return n;
}

static Nodo *nodo_asigna(int idx, Nodo *e) {
    Nodo *n = nuevo(N_ASIGNA, T_NUM);
    n->idx = idx; n->a = e;
    return n;
}
static Nodo *nodo_print(Nodo *e) { Nodo *n = nuevo(N_PRINT, e->tipo); n->a = e; return n; }

static Nodo *nodo_if(Nodo *c, Nodo *t, Nodo *e) {
    if (c->tipo != T_BOOL) error_sem("la condicion del if debe ser booleana");
    Nodo *n = nuevo(N_IF, T_NUM);
    n->a = c; n->b = t; n->c = e;
    return n;
}
static Nodo *nodo_while(Nodo *c, Nodo *cuerpo) {
    if (c->tipo != T_BOOL) error_sem("la condicion del while debe ser booleana");
    Nodo *n = nuevo(N_WHILE, T_NUM);
    n->a = c; n->b = cuerpo;
    return n;
}

static Nodo *agregar(Nodo *lista, Nodo *s) {
    if (s == NULL) return lista;
    if (lista == NULL) return s;
    Nodo *p = lista;
    while (p->sig) p = p->sig;
    p->sig = s;
    return lista;
}

static void ejecutar(Nodo *lista);
%}

%union { double val; char *id; struct Nodo *n; }

%token <val> NUM
%token <id>  ID
%token VAR IF ELSE WHILE PRINT TRUE FALSE AND OR NOT LE GE EQ NE

%left  OR
%left  AND
%nonassoc EQ NE
%nonassoc '<' '>' LE GE
%left  '+' '-'
%left  '*' '/'
%right NOT UMINUS

%type <n> expr sentencia bloque lista

%%
programa : /* vacio */
         | lista   { if (errores_sem == 0) ejecutar($1);
                     else fprintf(stderr, "\nSe encontraron %d error(es) semantico(s): el programa no se ejecuta.\n",
                                  errores_sem); }
         ;

lista    : sentencia          { $$ = $1; }
         | lista sentencia    { $$ = agregar($1, $2); }
         ;

bloque   : '{' '}'            { $$ = NULL; }
         | '{' lista '}'      { $$ = $2; }
         ;

sentencia
         : VAR ID '=' expr ';'
             { if (buscar_var($2) >= 0) {
                   error_sem("la variable '%s' ya fue declarada", $2);
                   $$ = NULL;
               } else {
                   if ($4->tipo != T_NUM)
                       error_sem("la variable '%s' solo puede almacenar numeros", $2);
                   $$ = nodo_asigna(declarar_var($2), $4);
               }
               free($2); }
         | ID '=' expr ';'
             { int i = buscar_var($1);
               if (i < 0) {
                   error_sem("la variable '%s' no ha sido declarada", $1);
                   $$ = NULL;
               } else {
                   if ($3->tipo != T_NUM)
                       error_sem("la variable '%s' solo puede almacenar numeros", $1);
                   $$ = nodo_asigna(i, $3);
               }
               free($1); }
         | PRINT expr ';'                          { $$ = nodo_print($2); }
         | IF '(' expr ')' bloque                  { $$ = nodo_if($3, $5, NULL); }
         | IF '(' expr ')' bloque ELSE bloque      { $$ = nodo_if($3, $5, $7); }
         | WHILE '(' expr ')' bloque               { $$ = nodo_while($3, $5); }
         ;

expr     : NUM                { $$ = nodo_const($1, T_NUM); }
         | TRUE               { $$ = nodo_const(1, T_BOOL); }
         | FALSE              { $$ = nodo_const(0, T_BOOL); }
         | ID                 { int i = buscar_var($1);
                                if (i < 0) {
                                    error_sem("la variable '%s' no ha sido declarada", $1);
                                    $$ = nodo_const(0, T_NUM);
                                } else $$ = nodo_var(i);
                                free($1); }
         | '(' expr ')'       { $$ = $2; }
         | expr '+' expr      { $$ = nodo_bin(OP_ADD, $1, $3); }
         | expr '-' expr      { $$ = nodo_bin(OP_SUB, $1, $3); }
         | expr '*' expr      { $$ = nodo_bin(OP_MUL, $1, $3); }
         | expr '/' expr      { $$ = nodo_bin(OP_DIV, $1, $3); }
         | expr '<' expr      { $$ = nodo_bin(OP_LT,  $1, $3); }
         | expr '>' expr      { $$ = nodo_bin(OP_GT,  $1, $3); }
         | expr LE  expr      { $$ = nodo_bin(OP_LE,  $1, $3); }
         | expr GE  expr      { $$ = nodo_bin(OP_GE,  $1, $3); }
         | expr EQ  expr      { $$ = nodo_bin(OP_EQ,  $1, $3); }
         | expr NE  expr      { $$ = nodo_bin(OP_NE,  $1, $3); }
         | expr AND expr      { $$ = nodo_bin(OP_AND, $1, $3); }
         | expr OR  expr      { $$ = nodo_bin(OP_OR,  $1, $3); }
         | '-' expr %prec UMINUS { $$ = nodo_un(N_NEG, $2); }
         | NOT expr           { $$ = nodo_un(N_NOT, $2); }
         ;
%%

/* ---------- interprete: recorre el AST ya validado ---------- */
static double evaluar(Nodo *n) {
    switch (n->kind) {
        case N_NUM: return n->val;
        case N_VAR: return tabla[n->idx].valor;
        case N_NEG: return -evaluar(n->a);
        case N_NOT: return !evaluar(n->a);
        case N_BIN: {
            double x = evaluar(n->a);
            if (n->op == OP_AND) return x && evaluar(n->b);   /* cortocircuito */
            if (n->op == OP_OR)  return x || evaluar(n->b);
            double y = evaluar(n->b);
            switch (n->op) {
                case OP_ADD: return x + y;
                case OP_SUB: return x - y;
                case OP_MUL: return x * y;
                case OP_DIV:
                    if (y == 0) { fprintf(stderr, "Error de ejecucion: division entre cero\n"); exit(1); }
                    return x / y;
                case OP_LT: return x <  y;
                case OP_GT: return x >  y;
                case OP_LE: return x <= y;
                case OP_GE: return x >= y;
                case OP_EQ: return x == y;
                case OP_NE: return x != y;
            }
        }
    }
    return 0;
}

static void ejecutar(Nodo *lista) {
    for (Nodo *n = lista; n != NULL; n = n->sig) {
        switch (n->kind) {
            case N_ASIGNA: tabla[n->idx].valor = evaluar(n->a); break;
            case N_PRINT:
                if (n->tipo == T_BOOL) printf("%s\n", evaluar(n->a) ? "true" : "false");
                else                   printf("%g\n", evaluar(n->a));
                break;
            case N_IF:
                if (evaluar(n->a)) ejecutar(n->b);
                else               ejecutar(n->c);
                break;
            case N_WHILE:
                while (evaluar(n->a)) ejecutar(n->b);
                break;
        }
    }
}

void yyerror(const char *s) {
    fprintf(stderr, "Error sintactico (linea %d): %s\n", yylineno, s);
}

int main(int argc, char **argv) {
    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (!yyin) { perror(argv[1]); return 1; }
    }
    int r = yyparse();
    return r || errores_sem;
}
