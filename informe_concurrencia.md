# Informe de Concurrencia — Escenario: Lectura No Repetible

## Escenario: Lectura No Repetible (Non-Repeatable Read)

### Aislamiento utilizado: `READ COMMITTED` (nivel por defecto de PostgreSQL)

---

## Código SQL ejecutado — Sesión A

```sql
BEGIN;

SELECT precio FROM producto WHERE id_producto = 1;
-- Primer SELECT dentro de la transacción

-- (espera ~3 segundos mientras la Sesión B ejecuta UPDATE + COMMIT)

SELECT precio FROM producto WHERE id_producto = 1;
-- Segundo SELECT dentro de la misma transacción

COMMIT;
```

### Salida Sesión A

```
BEGIN

 precio
---------
 1500.00
(1 row)

 precio
---------
 1800.00
(1 row)

COMMIT
```

---

## Código SQL ejecutado — Sesión B

```sql
BEGIN;

UPDATE producto SET precio = 1800.00 WHERE id_producto = 1;

COMMIT;
```

### Salida Sesión B

```
BEGIN

UPDATE 1

COMMIT
```

---

## Orden de ejecución cronológico

```
Tiempo ──────────────────────────────────────────────────────►

Sesión A:  BEGIN ──── SELECT (1500.00) ──── [duerme] ──── SELECT (1800.00) ──── COMMIT
Sesión B:                    ──── BEGIN ──── UPDATE ──── COMMIT ────
```

---

# Informe de Concurrencia — Escenario: Lectura Fantasma

## Escenario: Lectura Fantasma (Phantom Read)

### Aislamiento utilizado: `READ COMMITTED` (nivel por defecto de PostgreSQL)

---

## Código SQL ejecutado — Sesión A

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

### Salida Sesión A

```
BEGIN

 total_productos
-----------------
               5
(1 row)

 suma_precios
--------------
      1800.00
(1 row)

 total_productos
-----------------
               6
(1 row)

 suma_precios
--------------
      3000.00
(1 row)

COMMIT
```

---

## Código SQL ejecutado — Sesión B

```sql
BEGIN;

INSERT INTO producto (nombre, precio, stock, id_categoria)
VALUES ('Gaseosa cola 500ml', 1200.00, 50, 1);

COMMIT;
```

### Salida Sesión B

```
BEGIN

INSERT 0 1

COMMIT
```

---

## Orden de ejecución cronológico

```
Tiempo ──────────────────────────────────────────────────────────►

Sesión A:  BEGIN ──── COUNT (5) / SUM (1800) ──── [duerme] ──── COUNT (6) / SUM (3000) ──── COMMIT
Sesión B:                          ──── BEGIN ──── INSERT ──── COMMIT ────
```

---

---

# Informe de Concurrencia — Escenario: Espera por Bloqueo (FOR UPDATE)

## Escenario: Espera por Bloqueo — SELECT ... FOR UPDATE

### Aislamiento utilizado: `READ COMMITTED` (nivel por defecto de PostgreSQL)

---

## Código SQL ejecutado — Sesión A

```sql
BEGIN;

SELECT precio FROM producto WHERE id_producto = 1 FOR UPDATE;
-- Adquiere el bloqueo exclusivo sobre la fila

-- (espera ~5 segundos; la Sesión B intenta FOR UPDATE y se bloquea)

UPDATE producto SET precio = 2000.00 WHERE id_producto = 1;

COMMIT;
-- Libera el bloqueo; la Sesión B queda desbloqueada
```

### Salida Sesión A

```
BEGIN

 precio
---------
 1500.00
(1 row)

UPDATE 1

COMMIT
```

---

## Código SQL ejecutado — Sesión B

```sql
BEGIN;

SELECT precio FROM producto WHERE id_producto = 1 FOR UPDATE;
-- Se bloquea esperando a que la Sesión A libere el bloqueo (haga COMMIT o ROLLBACK)

-- (una vez desbloqueada, lee el precio ya actualizado)

SELECT precio FROM producto WHERE id_producto = 1;

COMMIT;
```

### Salida Sesión B

```
BEGIN

-- (espera bloqueada hasta que la Sesión A hace COMMIT)

 precio
---------
 2000.00
(1 row)

 precio
---------
 2000.00
(1 row)

COMMIT
```

---

## Orden de ejecución cronológico

```
Tiempo ──────────────────────────────────────────────────────────────►

Sesión A:  BEGIN ──── FOR UPDATE (bloquea fila) ──── [duerme 5s] ──── UPDATE ──── COMMIT ────
Sesión B:                          ──── BEGIN ──── FOR UPDATE (⚠ BLOQUEADA) ──────────── [desbloquea] ──── SELECT (2000.00) ──── COMMIT
```

---

## ¿Qué ocurrió?

La Sesión A ejecutó `SELECT ... FOR UPDATE` sobre la fila `id_producto = 1`, adquiriendo un **bloqueo exclusivo** (exclusive row lock) sobre esa fila. Mientras la Sesión A mantuvo el bloqueo, la Sesión B intentó ejecutar el mismo `SELECT ... FOR UPDATE` sobre la misma fila y **quedó bloqueada** (esperando), sin poder avanzar.

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
