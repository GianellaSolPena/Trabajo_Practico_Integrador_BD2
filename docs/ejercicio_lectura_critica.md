# Parte 3: Ejercicio de Lectura Crítica

## Script 1

-- Generado para: dar de baja las funciones de películas retiradas de cartel

```sql
UPDATE funcion
SET activa = FALSE;
```

# Filas que afectaria

Afectaria a todas las filas de la tabla funcion esto se debe a que carece de la clausula WHERE, la encargadad de filtrar registros, haciendo que se modifiquen todos los resigtros disponibles de la tabla 


# Correccion del Script 1

BEGIN;

UPDATE funcion
SET activa = FALSE
FROM pelicula
WHERE funcion.pelicula_id = pelicula.id
  AND pelicula.estado = 'RETIRADA'
  AND funcion.activa = TRUE;

COMMIT;

## Script 2

-- Generado para: limpiar las categorías sin productos asociados

```sql
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto);
```

# Filas que afectaria
Eliminaria a todas las categorias que no tengan un producto asociados siempre que ninguno de los valores de la subconsulta sea NULL. Por lo contrario si categoria_id en la tabla producto contiene al menos un valor NULL, la subconsulta (SELECT categoria_id FROM producto) devolverá un conjunto que incluye NULL y como consecuencia no borrarira ninguna fila.


# Correccion del Script 2
BEGIN;

DELETE FROM categoria c
WHERE NOT EXISTS (
    SELECT 1 
    FROM producto p
    WHERE p.categoria_id = c.id
);

COMMIT;


