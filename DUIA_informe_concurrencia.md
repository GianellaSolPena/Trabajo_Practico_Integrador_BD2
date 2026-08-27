# Informe de Concurrencia — Lectura No Repetible

## Configuración Inicial

**Base de datos:** Food Store
**Aislamiento actual:** `READ COMMITTED` (nivel por defecto de PostgreSQL)
**Tabla afectada:** `producto`
**Registro:** `id_producto = 1` (Agua mineral 500ml, precio inicial = 1500.00)

---

## Comandos Ejecutados

### Sesión A (comienza primero)

```sql
BEGIN;

SELECT precio FROM producto WHERE id_producto = 1;
-- Primer SELECT dentro de la transacción

-- (espera ~3 segundos mientras la Sesión B ejecuta UPDATE + COMMIT)

SELECT precio FROM producto WHERE id_producto = 1;
-- Segundo SELECT dentro de la misma transacción

COMMIT;
```

### Sesión B (se ejecuta mientras la Sesión A duerme)

```sql
BEGIN;

UPDATE producto SET precio = 1800.00 WHERE id_producto = 1;

COMMIT;
```

---

## Salidas Obtenidas

### Sesión A

| Paso | Comando | Resultado |
|------|---------|-----------|
| 1 | `BEGIN` | `BEGIN` |
| 2 | `SELECT precio FROM producto WHERE id_producto = 1;` (1er SELECT) | **precio = 1500.00** |
| 3 | *(espera ~3 segundos — la Sesión B actualiza y confirma)* | — |
| 4 | `SELECT precio FROM producto WHERE id_producto = 1;` (2do SELECT) | **precio = 1800.00** |
| 5 | `COMMIT` | `COMMIT` |

### Sesión B

| Paso | Comando | Resultado |
|------|---------|-----------|
| 1 | `BEGIN` | `BEGIN` |
| 2 | `UPDATE producto SET precio = 1800.00 WHERE id_producto = 1;` | `UPDATE 1` |
| 3 | `COMMIT` | `COMMIT` |

---

## ¿Qué ocurrió?

Dentro de una **misma transacción** (Sesión A), dos `SELECT` consecutivos sobre la **misma fila** devolvieron **valores distintos**:

- **Primera lectura:** 1500.00
- **Segunda lectura:** 1800.00

Esto sucede porque el nivel de aislamiento `READ COMMITTED` permite que una transacción lea los últimos datos **confirmados** (commiteados) en cada consulta. Cuando la Sesión B ejecuta `COMMIT` con el precio nuevo, la Sesión A —al volver a consultar— lee la versión ya actualizada del registro, aunque esté dentro de la misma transacción.

Este fenómeno se conoce como **lectura no repetible** (*non-repeatable read*): la misma consulta ejecutada dos veces dentro de una transacción retorna resultados diferentes porque otra transacción modificó y confirmó los datos entre ambas lecturas.

---

## ¿Qué nivel de aislamiento lo evitaría?

El nivel de aislamiento que previene las lecturas no repetibles es **`REPEATABLE READ`**.

| Nivel de aislamiento | ¿Previene lectura no repetible? |
|----------------------|---------------------------------|
| `READ COMMITTED` | No — lee la última versión commiteada en cada `SELECT` |
| `REPEATABLE READ` | **Sí** — garantiza que todas las lecturas dentro de una transacción vean el snapshot tomado al inicio de la transacción |
| `SERIALIZABLE` | Sí — previene lectura no repetible y además serializa transacciones concurrentes |

### Mecanismo subyacente (PostgreSQL)

PostgreSQL implementa `REPEATABLE READ` mediante **MVCC (Multi-Version Concurrency Control)**:

1. Al iniciar la transacción con `BEGIN` en nivel `REPEATABLE READ`, se toma un **snapshot** del estado de la base de datos.
2. Todas las lecturas dentro de esa transacción consultan **exclusivamente** ese snapshot.
3. Si otra transacción modifica y confirma datos después del snapshot, la transacción original **no ve** esos cambios — sigue viendo los datos del momento en que comenzó.
4. Si la transacción original intenta `UPDATE` sobre una fila modificada por otra transacción ya commiteada, recibe un error de serialización y debe reintentar.

### Para evitarlo se debería ejecutar:

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ;

-- Todas las lecturas verán el snapshot del inicio
SELECT precio FROM producto WHERE id_producto = 1;  -- 1500.00
-- (la Sesión B actualiza y commitea)
SELECT precio FROM producto WHERE id_producto = 1;  -- sigue 1500.00

COMMIT;
```

---

---

# Informe de Concurrencia — Escenario: Lectura Fantasma

## Configuración Inicial

**Base de datos:** Food Store
**Aislamiento actual:** `READ COMMITTED` (nivel por defecto de PostgreSQL)
**Tabla afectada:** `producto`
**Condición del WHERE:** `id_categoria = 1`

---

## Comandos Ejecutados

### Sesión A (comienza primero)

```sql
BEGIN;

SELECT COUNT(*) AS total_productos FROM producto;
SELECT SUM(precio) AS suma_precios FROM producto WHERE id_categoria = 1;
-- Primer COUNT/SUM dentro de la transacción

-- (espera ~3 segundos mientras la Sesión B ejecuta INSERT + COMMIT)

SELECT COUNT(*) AS total_productos FROM producto;
SELECT SUM(precio) AS suma_precios FROM producto WHERE id_categoria = 1;
-- Segundo COUNT/SUM dentro de la misma transacción

COMMIT;
```

### Sesión B (se ejecuta mientras la Sesión A duerme)

```sql
BEGIN;

INSERT INTO producto (nombre, precio, stock, id_categoria)
VALUES ('Gaseosa cola 500ml', 1200.00, 50, 1);

COMMIT;
```

---

## Salidas Obtenidas

### Sesión A

| Paso | Comando | Resultado |
|------|---------|-----------|
| 1 | `BEGIN` | `BEGIN` |
| 2 | `SELECT COUNT(*) AS total_productos FROM producto;` (1er COUNT) | **total_productos = 5** |
| 3 | `SELECT SUM(precio) AS suma_precios FROM producto WHERE id_categoria = 1;` (1er SUM) | **suma_precios = 1500.00** |
| 4 | *(espera ~3 segundos — la Sesión B inserta y confirma)* | — |
| 5 | `SELECT COUNT(*) AS total_productos FROM producto;` (2do COUNT) | **total_productos = 6** |
| 6 | `SELECT SUM(precio) AS suma_precios FROM producto WHERE id_categoria = 1;` (2do SUM) | **suma_precios = 2700.00** |
| 7 | `COMMIT` | `COMMIT` |

### Sesión B

| Paso | Comando | Resultado |
|------|---------|-----------|
| 1 | `BEGIN` | `BEGIN` |
| 2 | `INSERT INTO producto (nombre, precio, stock, id_categoria) VALUES ('Gaseosa cola 500ml', 1200.00, 50, 1);` | `INSERT 0 1` |
| 3 | `COMMIT` | `COMMIT` |

---

## ¿Qué ocurrió?

Dentro de una **misma transacción** (Sesión A), un `COUNT` y un `SUM` ejecutados dos veces con la misma condición `WHERE` retornaron **resultados distintos**:

| Operación | 1ra lectura | 2da lectura |
|-----------|-------------|-------------|
| `COUNT(*)` | 5 productos | **6 productos** |
| `SUM(precio) WHERE id_categoria = 1` | 1500.00 | **2700.00** |

Esto sucede porque la Sesión B insertó una nueva fila (`Gaseosa cola 500ml`) y ejecutó `COMMIT` entre ambas lecturas de la Sesión A. En nivel `READ COMMITTED`, cada consulta lee los datos **commiteados al momento de ejecutarse**, por lo que la segunda lectura ve la fila nueva que no existía en la primera.

Este fenómeno se conoce como **lectura fantasma** (*phantom read*): una segunda consulta dentro de la misma transacción retorna **filas nuevas** (fantasmas) que no existían en la primera consulta, porque otra transacción insertó datos que satisfacen la condición del `WHERE` y los confirmó.

---

## ¿Qué nivel de aislamiento lo evitaría?

El nivel de aislamiento que previene las lecturas fantasma es **`SERIALIZABLE`**.

| Nivel de aislamiento | ¿Previene lectura fantasma? |
|----------------------|-----------------------------|
| `READ COMMITTED` | No — cada `SELECT` lee los datos commiteados al momento |
| `REPEATABLE READ` | No — previene lectura no repetible pero **no** fantasma (en PostgreSQL sí puede ocurrir phantom con `REPEATABLE READ`) |
| `SERIALIZABLE` | **Sí** — bloquea rangos completos, impide inserciones que satisfagan el `WHERE` de consultas anteriores |

### Para evitarlo se debería ejecutar:

```sql
BEGIN ISOLATION LEVEL SERIALIZABLE;

SELECT COUNT(*) AS total_productos FROM producto WHERE id_categoria = 1;  -- 5
-- (la Sesión B intenta INSERT con id_categoria = 1 → se bloquea o recibe error de serialización)
SELECT COUNT(*) AS total_productos FROM producto WHERE id_categoria = 1;  -- sigue 5

COMMIT;
```

---

---

# Informe de Concurrencia — Escenario: Espera por Bloqueo (FOR UPDATE)

## Configuración Inicial

**Base de datos:** Food Store
**Aislamiento actual:** `READ COMMITTED` (nivel por defecto de PostgreSQL)
**Tabla afectada:** `producto`
**Registro:** `id_producto = 1` (precio = 1500.00)

---

## Comandos Ejecutados

### Sesión A (comienza primero)

```sql
BEGIN;

SELECT precio FROM producto WHERE id_producto = 1 FOR UPDATE;
-- Adquiere el bloqueo exclusivo sobre la fila

-- (espera ~5 segundos mientras la Sesión B intenta FOR UPDATE y queda bloqueada)

UPDATE producto SET precio = 2000.00 WHERE id_producto = 1;

COMMIT;
-- Libera el bloqueo; la Sesión B queda desbloqueada
```

### Sesión B (se ejecuta mientras la Sesión A duerme)

```sql
BEGIN;

SELECT precio FROM producto WHERE id_producto = 1 FOR UPDATE;
-- Se bloquea esperando a que la Sesión A libere el bloqueo (haga COMMIT o ROLLBACK)

-- (una vez desbloqueada, lee el precio ya actualizado)

SELECT precio FROM producto WHERE id_producto = 1;

COMMIT;
```

---

## Salidas Obtenidas

### Sesión A

| Paso | Comando | Resultado |
|------|---------|-----------|
| 1 | `BEGIN` | `BEGIN` |
| 2 | `SELECT precio FROM producto WHERE id_producto = 1 FOR UPDATE;` | **precio = 1500.00** (bloqueo adquirido) |
| 3 | *(espera ~5 segundos — la Sesión B queda bloqueada)* | — |
| 4 | `UPDATE producto SET precio = 2000.00 WHERE id_producto = 1;` | `UPDATE 1` |
| 5 | `COMMIT` | `COMMIT` (bloqueo liberado) |

### Sesión B

| Paso | Comando | Resultado |
|------|---------|-----------|
| 1 | `BEGIN` | `BEGIN` |
| 2 | `SELECT precio FROM producto WHERE id_producto = 1 FOR UPDATE;` | *(espera bloqueada hasta que la Sesión A hace COMMIT)* |
| 2b | *(desbloqueada tras COMMIT de A)* | **precio = 2000.00** |
| 3 | `SELECT precio FROM producto WHERE id_producto = 1;` | **precio = 2000.00** |
| 4 | `COMMIT` | `COMMIT` |

---

## ¿Qué ocurrió?

La Sesión A ejecutó `SELECT ... FOR UPDATE` sobre la fila `id_producto = 1`, adquiriendo un **bloqueo exclusivo** (exclusive row lock) sobre esa fila. Mientras la Sesión A mantuvo el bloqueo, la Sesión B intentó ejecutar el mismo `SELECT ... FOR UPDATE` sobre la **misma fila** y **quedó bloqueada** (esperando), sin poder avanzar.

La Sesión B solo pudo continuar después de que la Sesión A ejecutó `COMMIT`, liberando el bloqueo. En ese momento, la Sesión B leyó el precio ya actualizado (2000.00).

Este mecanismo es el **piso mínimo** de protección: `SELECT ... FOR UPDATE` adquiere un bloqueo pesimista que impide que otras transacciones modifiquen o bloqueen la misma fila hasta que se libere.

---

## ¿Qué nivel de aislamiento lo maneja?

| Nivel de aislamiento | Comportamiento con FOR UPDATE |
|----------------------|-------------------------------|
| `READ COMMITTED` | La fila se bloquea; la segunda sesión espera al COMMIT de la primera. Tras desbloquearse, lee la versión más reciente commiteada. |
| `REPEATABLE READ` | Igual comportamiento de bloqueo; la diferencia es que las lecturas posteriores dentro de la misma transacción ven el snapshot original. |
| `SERIALIZABLE` | Bloqueo a nivel de rangos; previene tanto bloqueo de filas como inserciones fantasma. |

En todos los niveles, `SELECT ... FOR UPDATE` adquiere un **row-level lock exclusivo** que fuerza a las sesiones concurrentes a esperar. La diferencia entre niveles es qué ocurre **después** del desbloqueo con las lecturas subsiguientes.
