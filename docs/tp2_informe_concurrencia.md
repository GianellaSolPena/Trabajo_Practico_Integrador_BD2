## EXPERIMENTO Espera por Bloqueo (Read Committed vs. Repeatable Read)

### Caso 1: Nivel por Defecto (`Read Committed`)

#### Orden de Ejecución Intercalado

| Orden | Sesión A (terminal 1) | Sesión B (terminal 2) |
|-------|----------------------|----------------------|
| 1 | `BEGIN;` | |
| 2 | `UPDATE producto SET precio = precio * 1.10 WHERE id_producto = 1;`<br>*Salida: `UPDATE 1` — toma el lock de escritura sobre la fila* | |
| 3 | | `BEGIN;` |
| 4 | | `UPDATE producto SET precio = precio * 1.10 WHERE id_producto = 1;`<br>**SE BLOQUEA** — la terminal queda sin responder, esperando el lock |
| 5 | `COMMIT;` — *libera el lock* | **Se desbloquea y aplica su UPDATE** → `UPDATE 1` |
| 6 | | `COMMIT;` |

---

### Caso 2: Nivel `Repeatable Read`

#### Orden de Ejecución Intercalado

| Orden | Sesión A (terminal 1) | Sesión B (terminal 2) |
|-------|----------------------|----------------------|
| 1 | `BEGIN;` | |
| 2 | `UPDATE producto SET precio = precio * 1.10 WHERE id_producto = 1;`<br>*Salida: `UPDATE 1`* | |
| 3 | | `BEGIN ISOLATION LEVEL REPEATABLE READ;` |
| 4 | | `UPDATE producto SET precio = precio * 1.10 WHERE id_producto = 1;`<br>**SE BLOQUEA** — la terminal queda sin responder |
| 5 | `COMMIT;` — *libera el lock* | **Se desbloquea y aplica su UPDATE** → `UPDATE 1` |
| 6 | | `COMMIT;` |

---

### Explicación de la ejecución (IA)

**Caso 1 (Read Committed)**
- Qué pasó: A toma el lock de escritura de la fila (UPDATE sobre el producto 1, sin commit). B intenta el mismo UPDATE sobre la misma fila y **queda bloqueada**: PostgreSQL pone a B en espera hasta que A libere el lock con `COMMIT` (o `ROLLBACK`). Cuando A commitea, B se desbloquea y aplica su UPDATE. → se reproduce el fenómeno de **espera por bloqueo**.
- Qué lo resolvería: mantener las transacciones lo más cortas posible, usar `SET lock_timeout = '3s'` para fallar en vez de esperar indefinidamente, o `SELECT ... FOR UPDATE NOWAIT` para reintentar.

**Caso 2 (Repeatable Read)**
- Qué pasó: con REPEATABLE READ el bloqueo de escritura se comporta igual: B espera el lock. El nivel de aislamiento protege las **lecturas** (snapshots), pero no elimina la espera de una **escritura-escritura** sobre la misma fila: ese serializado lo resuelve el motor con locks, en cualquier nivel.
- Qué lo resolvería: los mismos mecanismos del Caso 1 (transacciones cortas, `lock_timeout`, `NOWAIT`). La espera por bloqueo no es una anomalía: es el mecanismo del motor para serializar escrituras concurrentes.

> **Autocrítica:** en la primera versión de este experimento la sesión B solo hacía `SELECT`s, que con MVCC nunca esperan por locks, por lo que el fenómeno no se reproducía. La secuencia se corrigió para que B ejecute un `UPDATE` sobre la misma fila bloqueada por A.

---

## EXPERIMENTO Lectura Fantasma (Phantom Read)

### Caso 1 `Read Committed`

#### Orden de Ejecución Intercalado
1. **[Sesión B]** `BEGIN;`
2. **[Sesión B]** `SELECT COUNT(*) FROM detalle_pedido WHERE id_pedido = 1;`
   ```text
    count 
   -------
        1
   (1 row)
   ```
3. **[Sesión A]** `BEGIN;`
4. **[Sesión A]** `INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (1, 3, 2, 450.00);`
   - *Salida:* `INSERT 0 1`
5. **[Sesión A]** `COMMIT;`
6. **[Sesión B]** `SELECT COUNT(*) FROM detalle_pedido WHERE id_pedido = 1;`
   ```text
    count 
   -------
        2
   (1 row)
   ```
7. **[Sesión B]** `COMMIT;`

---

### Caso 2: Nivel `Repeatable Read`

#### Orden de Ejecución Intercalado
1. **[Sesión B]** `BEGIN ISOLATION LEVEL REPEATABLE READ;`
2. **[Sesión B]** `SELECT COUNT(*) FROM detalle_pedido WHERE id_pedido = 1;`
   ```text
    count 
   -------
        2
   (1 row)
   ```
3. **[Sesión A]** `BEGIN;`
4. **[Sesión A]** `INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (1, 2, 1, 450.00);`
   - *Salida:* `INSERT 0 1`
5. **[Sesión A]** `COMMIT;`
6. **[Sesión B]** `SELECT COUNT(*) FROM detalle_pedido WHERE id_pedido = 1;`
   ```text
    count 
   -------
        2
   (1 row)
   ```
7. **[Sesión B]** `COMMIT;`

---
### Explicación de la ejecución (IA)
Caso 1 (Read Committed)
- Qué pasó: B cuenta 1 detalle del pedido 1; A inserta una fila y commitea; B recuenta y ve 2 → LECTURA FANTASMA (aparece una fila nueva durante la transacción).
- Qué lo evitaría: En PostgreSQL, REPEATABLE READ ya evita phantoms (la snapshot no ve el INSERT posterior commiteado) y SERIALIZABLE también. Como mecanismo de bloqueo clásico: gap/range locks sobre el rango consultado (es lo que hace MySQL/InnoDB; Postgres lo logra vía snapshot).

Caso 2 (Repeatable Read)
- Qué pasó: B cuenta 2; A inserta otra fila y commitea; B recuenta y sigue viendo 2 porque la fila nueva no está en su snapshot → sin phantoms.
- Qué lo evitaría: Ya prevenido por RR/SERIALIZABLE.

--- 
## EXPERIMENTO Lectura No Repetible (Non-Repeatable Read) — tabla `producto` (stock)

### Caso 1: Nivel `Read Committed`

#### Orden de Ejecución Intercalado
1. **[Sesión B]** `BEGIN;`
2. **[Sesión B]** `SELECT stock FROM producto WHERE id_producto = 1;`
   ```text
    stock 
   -------
    240
   (1 row)
   ```
3. **[Sesión A]** `BEGIN;`
4. **[Sesión A]** `UPDATE producto SET stock = stock - 5 WHERE id_producto = 1;`
   - *Salida:* `UPDATE 1`
5. **[Sesión A]** `COMMIT;`
6. **[Sesión B]** `SELECT stock FROM producto WHERE id_producto = 1;`
   ```text
    stock 
   -------
    235
   (1 row)
   ```
7. **[Sesión B]** `COMMIT;`

---

### Caso 2: Nivel `Repeatable Read`

#### Orden de Ejecución Intercalado
1. **[Sesión B]** `BEGIN ISOLATION LEVEL REPEATABLE READ;`
2. **[Sesión B]** `SELECT stock FROM producto WHERE id_producto = 1;`
   ```text
    stock 
   -------
    235
   (1 row)
   ```
3. **[Sesión A]** `BEGIN;`
4. **[Sesión A]** `UPDATE producto SET stock = stock - 5 WHERE id_producto = 1;`
   - *Salida:* `UPDATE 1`
5. **[Sesión A]** `COMMIT;`
6. **[Sesión B]** `SELECT stock FROM producto WHERE id_producto = 1;`
   ```text
    stock 
   -------
    235
   (1 row)
   ```
7. **[Sesión B]** `COMMIT;`

---
### Explicación de la ejecución (IA)

Caso 1 (Read Committed)
- Qué pasó: B lee stock=240; A descuenta 5 y commitea (queda 235); B relee y ve 235 → LECTURA NO REPETIBLE. En RC cada sentencia abre un snapshot nuevo y ve el último commit.
- Qué lo evitaría: REPEATABLE READ (la segunda lectura vuelve a dar 240) o SERIALIZABLE. Alternativa clásica de bloqueo: locks compartidos de lectura mantenidos hasta el commit (tipo SELECT ... FOR SHARE).

Caso 2 (Repeatable Read)
- Qué pasó: B lee 235; A descuenta a 230 y commitea; B relee y sigue viendo 235 (misma snapshot) → comportamiento correcto, sin anomalía.
- Qué lo evitaría: Ya está prevenido; solo hay que no bajar a RC. Nota: si B intentara ahora escribir basado en ese valor viejo, RR lanzaría un error de serialización (40001), evitando también la pérdida de actualización.
---