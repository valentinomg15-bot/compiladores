%code requires {
#include "units.h"
}

%{
#include <stdio.h>
#include <string.h>
#include "units.h"

int  yylex(void);
void yyerror(const char *s);

static const char *NOMBRE_CAT[] = { "longitud", "masa", "volumen", "temperatura" };

/* Tabla de unidades: simbolo, nombre, categoria, sistema, factor a la base
   Bases: metro, kilogramo, litro y kelvin (la temperatura se trata aparte). */
static const Unidad TABLA[] = {
    {"mm",   "milimetro",       C_LONG, SIS_SI,  0.001},
    {"cm",   "centimetro",      C_LONG, SIS_SI,  0.01},
    {"m",    "metro",           C_LONG, SIS_SI,  1.0},
    {"km",   "kilometro",       C_LONG, SIS_SI,  1000.0},
    {"in",   "pulgada",         C_LONG, SIS_ING, 0.0254},
    {"ft",   "pie",             C_LONG, SIS_ING, 0.3048},
    {"yd",   "yarda",           C_LONG, SIS_ING, 0.9144},
    {"mi",   "milla",           C_LONG, SIS_ING, 1609.344},
    {"g",    "gramo",           C_MASA, SIS_SI,  0.001},
    {"kg",   "kilogramo",       C_MASA, SIS_SI,  1.0},
    {"oz",   "onza",            C_MASA, SIS_ING, 0.028349523125},
    {"lb",   "libra",           C_MASA, SIS_ING, 0.45359237},
    {"ml",   "mililitro",       C_VOL,  SIS_SI,  0.001},
    {"l",    "litro",           C_VOL,  SIS_SI,  1.0},
    {"L",    "litro",           C_VOL,  SIS_SI,  1.0},
    {"floz", "onza liquida",    C_VOL,  SIS_ING, 0.0295735295625},
    {"gal",  "galon",           C_VOL,  SIS_ING, 3.785411784},
    {"C",    "grado Celsius",   C_TEMP, SIS_SI,  0.0},
    {"K",    "kelvin",          C_TEMP, SIS_SI,  0.0},
    {"F",    "grado Fahrenheit",C_TEMP, SIS_ING, 0.0}
};
#define N_UNIDADES ((int)(sizeof(TABLA) / sizeof(TABLA[0])))

const Unidad *buscar_unidad(const char *s) {
    for (int i = 0; i < N_UNIDADES; i++)
        if (strcmp(TABLA[i].simbolo, s) == 0) return &TABLA[i];
    return NULL;
}

/* valor en unidad u -> valor en la unidad base */
static double a_base(double v, const Unidad *u) {
    if (u->cat == C_TEMP) {
        if (u->simbolo[0] == 'C') return v + 273.15;
        if (u->simbolo[0] == 'F') return (v - 32.0) * 5.0 / 9.0 + 273.15;
        return v;                              /* K */
    }
    return v * u->factor;
}

/* valor en la unidad base -> valor en unidad u */
static double desde_base(double b, const Unidad *u) {
    if (u->cat == C_TEMP) {
        if (u->simbolo[0] == 'C') return b - 273.15;
        if (u->simbolo[0] == 'F') return (b - 273.15) * 9.0 / 5.0 + 32.0;
        return b;                              /* K */
    }
    return b / u->factor;
}

/* comprobacion semantica: el valor es fisicamente posible */
static int valido(double v, const Unidad *u) {
    if (u->cat == C_TEMP) {
        if (a_base(v, u) < 0.0) {
            fprintf(stderr, "Error semantico: temperatura por debajo del cero absoluto\n");
            return 0;
        }
    } else if (v < 0.0) {
        fprintf(stderr, "Error semantico: una magnitud de %s no puede ser negativa\n",
                NOMBRE_CAT[u->cat]);
        return 0;
    }
    return 1;
}

static void mostrar(double v, const Unidad *o, const Unidad *d) {
    printf("%g %s = %.4f %s\n", v, o->simbolo, desde_base(a_base(v, o), d), d->simbolo);
}

/* forma corta: convierte a TODAS las unidades inglesas de la misma categoria */
static void a_ingles(double v, const Unidad *o) {
    if (o->sis != SIS_SI) {
        fprintf(stderr, "Error semantico: '%s' no es una unidad del Sistema Internacional\n", o->simbolo);
        return;
    }
    for (int i = 0; i < N_UNIDADES; i++)
        if (TABLA[i].cat == o->cat && TABLA[i].sis == SIS_ING)
            mostrar(v, o, &TABLA[i]);
}
%}

%union { double val; const Unidad *u; }

%token <val> NUM
%token <u>   UNIT
%token TO EOL UNKNOWN

%type <val> valor

%%
entrada : /* vacio */
        | entrada linea
        ;

linea   : EOL
        | valor UNIT EOL
            { if (valido($1, $2)) a_ingles($1, $2); }
        | valor UNIT TO UNIT EOL
            { if ($2->cat != $4->cat)
                  fprintf(stderr, "Error semantico: no se puede convertir %s a %s\n",
                          NOMBRE_CAT[$2->cat], NOMBRE_CAT[$4->cat]);
              else if (valido($1, $2))
                  mostrar($1, $2, $4); }
        | error EOL
            { yyerrok; }
        ;

valor   : NUM        { $$ = $1; }
        | '-' NUM    { $$ = -$2; }
        ;
%%

void yyerror(const char *s) {
    fprintf(stderr, "Error sintactico: %s\n", s);
}

int main(void) {
    printf("Conversor SI -> Sistema Ingles. Ejemplos: '100 km'  |  '5 mi to km'  (Ctrl+D para salir)\n");
    return yyparse();
}
