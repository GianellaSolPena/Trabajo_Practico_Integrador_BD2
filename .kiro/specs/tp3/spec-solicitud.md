# Consultas SQL — FoodStore

## 1. Primera consulta: Resumen

### Prompt

> Generar una consulta SQL sobre el esquema de la base de datos **FoodStore** que devuelva, para los pedidos cuyo estado sea `TERMINADO`, cada producto que aparece en su detalle de pedido, siempre que el producto no esté eliminado lógicamente (`deleted_at IS NULL`).
>
> La consulta debe mostrar:
>
> * El nombre del producto.
> * La cantidad total de veces que aparece ese producto, utilizando la función `SUM(cantidad)`.
> * Los nombres de los productos ordenados alfabéticamente de A a Z mediante `ORDER BY`.
>
> **Tablas involucradas:** `pedido`, `producto` y `detalle_pedido`.

La consulta debe devolver una fila por cada producto, agrupando por id_producto y nombre

---

### Consulta A

```sql
SELECT p.nombre,
       SUM(d.cantidad) AS cantidad_total
FROM pedido pe
JOIN detalle_pedido d
    ON d.id_pedido = pe.id_pedido
JOIN producto p
    ON p.id_producto = d.id_producto
WHERE pe.estado = 'TERMINADO'
  AND p.deleted_at IS NULL
GROUP BY p.nombre
ORDER BY p.nombre ASC;
```

### Consulta B

**Alternativa que agrupa también por `id_producto`, lo que resulta más seguro en caso de que existan productos con nombres repetidos.**

```sql
SELECT p.nombre,
       SUM(d.cantidad) AS cantidad_total
FROM detalle_pedido d
JOIN pedido pe
    ON pe.id_pedido = d.id_pedido
JOIN producto p
    ON p.id_producto = d.id_producto
WHERE pe.estado = 'TERMINADO'
  AND p.deleted_at IS NULL
GROUP BY p.id_producto, p.nombre
ORDER BY p.nombre ASC;
```

### Equivalencia

Se compararon ambas consultas mediante operaciones `EXCEPT`:

```text
Consulta A EXCEPT Consulta B → 0 filas
Consulta B EXCEPT Consulta A → 0 filas
```

Ambas consultas devuelven **exactamente el mismo conjunto de filas**: 800 filas correspondientes a los productos presentes en pedidos con estado `TERMINADO`.

> **Conclusión:** Las consultas A y B son **equivalentes** para los datos analizados.

---

## 2. Segunda consulta: Subconsulta

### Prompt

> Generar una consulta SQL sobre el esquema de la base de datos **FoodStore** que devuelva los productos de la tabla `producto` cuyo precio sea mayor al precio promedio de todos los productos cuya categoría sea `Carnes y Aves`.
>
> La consulta debe mostrar:
>
> * El nombre del producto.
> * El precio del producto.
>
> **Tabla principal:** `producto`.

---

### Consulta A

Esta consulta utiliza una **subconsulta escalar** para calcular el precio promedio de los productos de la categoría `Carnes y Aves`.

```sql
SELECT p.nombre,
       p.precio
FROM producto p
WHERE p.precio > (
    SELECT AVG(p2.precio)
    FROM producto p2
    JOIN categoria c
        ON c.id_categoria = p2.id_categoria
    WHERE c.nombre = 'Carnes y Aves'
      AND p2.deleted_at IS NULL
)
  AND p.deleted_at IS NULL
ORDER BY p.nombre;
```

### Consulta B

**Alternativa funcional utilizando una expresión `WITH` (CTE).**

```sql
WITH promedio_carnes AS (
    SELECT AVG(p2.precio) AS precio_promedio
    FROM producto p2
    JOIN categoria c
        ON c.id_categoria = p2.id_categoria
    WHERE c.nombre = 'Carnes y Aves'
      AND p2.deleted_at IS NULL
)

SELECT p.nombre,
       p.precio
FROM producto p, promedio_carnes pc
WHERE p.precio > pc.precio_promedio
  AND p.deleted_at IS NULL
ORDER BY p.nombre;
```

### Equivalencia

Para comprobar que ambas consultas producen el mismo resultado, se realizaron las siguientes comparaciones:

```text
Consulta A EXCEPT Consulta B → 0 filas
Consulta B EXCEPT Consulta A → 0 filas
```

Ambas consultas devuelven **exactamente el mismo conjunto de filas**: **24.563 productos** cuyo precio es superior a **$259,12**, correspondiente al precio promedio calculado para la categoría `Carnes y Aves`.

> **Conclusión:** Las consultas A y B son **equivalentes** y producen el mismo resultado sobre los datos analizados.


