# Parte 2: Anomalías con Dos Sesiones Concurrentes

## EXPERIMENTOS SELECCIONADOS


# EXPERIMENTO 1: Espera por Bloqueo (Read Committed vs. Repeatable Read)
Informe del experimento: informe_concurrencia_espera_por_bloqueo.md

# EXPERIMENTO 2: Lectura No Repetible (Non-Repeatable Read)
Informe del experimento: informe_concurrencia_lectura_no_repetible.md
 
# EXPERIMENTO 3:  Lectura Fantasma (Phantom Read)
Informe del experimento: informe_concurrencia_lectura_fantasma.md


## EXPLICACION DE LOS 3 CASOS POR LA IA

### 1. Espera por bloqueo (Lock Waiting) — tabla `producto`

En PostgreSQL, cuando una sesión ejecuta un `UPDATE` (o `SELECT ... FOR UPDATE`) sobre una fila, adquiere un **bloqueo exclusivo a nivel de fila**. Si una segunda sesión intenta modificar la misma fila (o leerla con `FOR UPDATE`), el motor la **pone en espera** hasta que la primera sesión libere el lock con `COMMIT` o `ROLLBACK`. Mientras tanto, la segunda sesión queda bloqueada y no avanza.

**Fenómeno:** Sesión B se bloquea intentando acceder a la misma fila que la Sesión A tiene lockeada. Solo se desbloquea cuando A confirma o revierte su transacción.

**Secuencia SQL para reproducirlo:**

| Orden | Sesión A (terminal 1) | Sesión B (terminal 2) |
|-------|----------------------|----------------------|
| 1 | `BEGIN;` | |
| 2 | `UPDATE producto SET stock = stock - 1 WHERE id_producto = 1;` | |
| | *(fila lockeada, no commiteado)* | |
| 3 | | `BEGIN;` |
| 4 | | `UPDATE producto SET stock = stock - 1 WHERE id_producto = 1;` |
| | | **SE BLOQUEA** — la terminal no responde, espera el lock |
| 5 | `COMMIT;` | |
| | *(libera el lock)* | **Se desbloquea y ejecuta el UPDATE** |
| 6 | | `COMMIT;` |

---

### 2. Lectura no repetible (Non-Repeatable Read) — tabla `producto`

Una **lectura no repetible** ocurre cuando una transacción ejecuta la misma consulta dos veces y obtiene resultados diferentes, porque otra sesión modificó y commiteó los datos entre ambas lecturas.

- **READ COMMITTED:** cada `SELECT` dentro de la transacción ve los datos commiteados al momento de ejecutarse. Si entre el primer y segundo `SELECT` otra transacción commiteó un `UPDATE`, el segundo `SELECT` verá el valor nuevo. → **Lectura no repetible sí ocurre.**
- **REPEATABLE READ:** la transacción toma un snapshot al iniciar y todos los `SELECT` ven la misma versión de los datos durante toda la transacción. → **Lectura no repetible NO ocurre.**

**Secuencia SQL — Prueba con READ COMMITTED (sí ocurre):**

| Orden | Sesión A (terminal 1) | Sesión B (terminal 2) |
|-------|----------------------|----------------------|
| 1 | `BEGIN;` | |
| 2 | `SET TRANSACTION ISOLATION LEVEL READ COMMITTED;` | |
| 3 | `SELECT id_producto, precio FROM producto WHERE id_producto = 1;` | |
| | → resultado: `precio = 1500.00` | |
| 4 | | `BEGIN;` |
| 5 | | `UPDATE producto SET precio = 9999.00 WHERE id_producto = 1;` |
| 6 | | `COMMIT;` |
| 7 | `SELECT id_producto, precio FROM producto WHERE id_producto = 1;` | |
| | → resultado: **`precio = 9999.00`** ← CAMBIÓ | |
| 8 | `ROLLBACK;` | |

El mismo `SELECT` ejecutado dos veces dentro de la misma transacción devolvió valores distintos (1500.00 y luego 9999.00). Eso es una lectura no repetible.

**Secuencia SQL — Prueba con REPEATABLE READ (no ocurre):**

| Orden | Sesión A (terminal 1) | Sesión B (terminal 2) |
|-------|----------------------|----------------------|
| 1 | `BEGIN;` | |
| 2 | `SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;` | |
| 3 | `SELECT id_producto, precio FROM producto WHERE id_producto = 1;` | |
| | → resultado: `precio = 1500.00` | |
| 4 | | `BEGIN;` |
| 5 | | `UPDATE producto SET precio = 9999.00 WHERE id_producto = 1;` |
| 6 | | `COMMIT;` |
| 7 | `SELECT id_producto, precio FROM producto WHERE id_producto = 1;` | |
| | → resultado: **`precio = 1500.00`** ← NO CAMBIÓ | |
| 8 | `ROLLBACK;` | |

El segundo `SELECT` sigue devolviendo 1500.00, el snapshot de la transacción A lo mantiene. No hay lectura no repetible.

---

### 3. Lectura Fantasma (Phantom Read) — tabla `detalle_pedido`

Una **lectura fantasma** ocurre cuando una transacción ejecuta una consulta agregada (`COUNT`, `SUM`) dos veces y obtiene resultados diferentes, porque otra sesión **insertó filas nuevas** que cumplen con la condición `WHERE` de la consulta y commiteó entre ambas ejecuciones. A diferencia de la lectura no repetible (que se produce por un `UPDATE` sobre filas existentes), el fantasma se produce por filas nuevas que aparecen.

En PostgreSQL: **READ COMMITTED** permite fantasmas. **REPEATABLE READ** los previene porque usa snapshot isolation.

**Secuencia SQL — Prueba con READ COMMITTED (fantasma sí ocurre):**

| Orden | Sesión A (terminal 1) | Sesión B (terminal 2) |
|-------|----------------------|----------------------|
| 1 | `BEGIN;` | |
| 2 | `SELECT COUNT(*) AS total_lineas FROM detalle_pedido WHERE id_pedido = 1;` | |
| | → resultado: `total_lineas = 1` | |
| 3 | `SELECT SUM(cantidad) AS total_cantidad FROM detalle_pedido WHERE id_pedido = 1;` | |
| | → resultado: `total_cantidad = 3` | |
| 4 | | `BEGIN;` |
| 5 | | `INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad) VALUES (1, 2, 5);` |
| 6 | | `COMMIT;` |
| 7 | `SELECT COUNT(*) AS total_lineas FROM detalle_pedido WHERE id_pedido = 1;` | |
| | → resultado: **`total_lineas = 2`** ← FANTASMA | |
| 8 | `SELECT SUM(cantidad) AS total_cantidad FROM detalle_pedido WHERE id_pedido = 1;` | |
| | → resultado: **`total_cantidad = 8`** ← FANTASMA | |
| 9 | `ROLLBACK;` | |

La primera vez `COUNT(*)` devolvió 1 y `SUM(cantidad)` devolvió 3. La segunda vez devolvió 2 y 8 respectivamente. La fila insertada por la Sesión B es un fantasma que apareció entre ambas lecturas.

**Secuencia SQL — Prueba con REPEATABLE READ (fantasma no ocurre):**

| Orden | Sesión A (terminal 1) | Sesión B (terminal 2) |
|-------|----------------------|----------------------|
| 1 | `BEGIN;` | |
| 2 | `SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;` | |
| 3 | `SELECT COUNT(*) AS total_lineas FROM detalle_pedido WHERE id_pedido = 1;` | |
| | → resultado: `total_lineas = 1` | |
| 4 | `SELECT SUM(cantidad) AS total_cantidad FROM detalle_pedido WHERE id_pedido = 1;` | |
| | → resultado: `total_cantidad = 3` | |
| 5 | | `BEGIN;` |
| 6 | | `INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad) VALUES (1, 2, 5);` |
| 7 | | `COMMIT;` |
| 8 | `SELECT COUNT(*) AS total_lineas FROM detalle_pedido WHERE id_pedido = 1;` | |
| | → resultado: **`total_lineas = 1`** ← NO CAMBIÓ | |
| 9 | `SELECT SUM(cantidad) AS total_cantidad FROM detalle_pedido WHERE id_pedido = 1;` | |
| | → resultado: **`total_cantidad = 3`** ← NO CAMBIÓ | |
| 10 | `ROLLBACK;` | |

> **Nota:** El estándar SQL dice que REPEATABLE READ no previene fantasmas, pero PostgreSQL lo implementa como snapshot isolation, que sí los previene en la práctica.

---

## COMO SOLUCIONARLO

### Solución a la espera por bloqueo

La espera por bloqueo es un comportamiento **normal y necesario** del motor para garantizar la integridad de los datos. No es un error en sí mismo, pero puede degradar el rendimiento si las transacciones mantienen locks largos. Las estrategias para mitigarlo son:

- **Mantener las transacciones lo más cortas posible:** no hacer operaciones lentas (lecturas externas, llamadas a APIs, procesamiento) dentro de una transacción que ya tomó locks.
- **Usar `SET lock_timeout`:** define un tiempo máximo de espera. Si la sesión no obtiene el lock en ese tiempo, falla con error en lugar de bloquearse indefinidamente.
  ```sql
  SET lock_timeout = '3s'; -- falla si no obtiene lock en 3 segundos
  ```
- **Ordenar los accesos:** si múltiples transacciones necesitan lockear las mismas filas, acceder a ellas en el mismo orden reduce la probabilidad de deadlocks.
- **Usar `SELECT ... FOR UPDATE NOWAIT`:** en lugar de esperar, falla inmediatamente si la fila ya está lockeada, permitiendo reintentar con otra lógica.
  ```sql
  SELECT * FROM producto WHERE id_producto = 1 FOR UPDATE NOWAIT;
  ```

### Solución a la lectura no repetible

La lectura no repetible se soluciona elevando el nivel de aislamiento:

- **Usar `REPEATABLE READ`:** toma un snapshot al inicio de la transacción y todos los `SELECT` ven la misma versión de los datos.
  ```sql
  BEGIN;
  SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
  -- ahora todas las lecturas son consistentes dentro de la transacción
  ```
- **Usar `SERIALIZABLE`:** el nivel más alto. No solo previene lecturas no repetibles, sino que serializa transacciones que podrían interferir entre sí (detecta dependencias de lectura-escritura).
  ```sql
  BEGIN;
  SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
  ```

### Solución a la lectura fantasma

La lectura fantasma se soluciona de forma similar, pero con matices según el motor:

- **En PostgreSQL, `REPEATABLE READ` ya previene fantasmas** gracias a su implementación de snapshot isolation. No es necesario subir a SERIALIZABLE solo por fantasmas.
- **Usar `SERIALIZABLE`:** si además se quiere prevenir anomalies como write skew, este nivel aplica bloqueos pesados (predicate locks) que detectan y rechazan transacciones serializables conflictivas.
  ```sql
  BEGIN;
  SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
  ```
- **Serializar la lógica de negocio:** si la aplicación necesita leer-contar-modificar, encapsular esa lógica en una función `PL/pgSQL` con `LOCK TABLE` o usar advisory locks para serializar el acceso a la tabla completa.
  ```sql
  -- Bloqueo a nivel de tabla completa (más pesado pero efectivo)
  LOCK TABLE detalle_pedido IN SHARE MODE;
  SELECT COUNT(*) FROM detalle_pedido WHERE id_pedido = 1;
  -- ... lógica de negocio ...
  ```

### Resumen de soluciones

| Escenario | Solución principal |
|-----------|-------------------|
| Espera por bloqueo | Transacciones cortas, `lock_timeout`, `FOR UPDATE NOWAIT` |
| Lectura no repetible | `SET TRANSACTION ISOLATION LEVEL REPEATABLE READ` |
| Lectura fantasma | `REPEATABLE READ` (en PostgreSQL) o `SERIALIZABLE` |


