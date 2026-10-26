#ifndef UNITS_H
#define UNITS_H

typedef enum { C_LONG, C_MASA, C_VOL, C_TEMP } Categoria;
typedef enum { SIS_SI, SIS_ING } Sistema;

typedef struct {
    const char *simbolo;   /* "km", "lb", ...                      */
    const char *nombre;    /* nombre completo                      */
    Categoria   cat;       /* longitud, masa, volumen, temperatura */
    Sistema     sis;       /* Sistema Internacional o Ingles       */
    double      factor;    /* factor hacia la unidad base          */
} Unidad;

const Unidad *buscar_unidad(const char *s);

#endif
