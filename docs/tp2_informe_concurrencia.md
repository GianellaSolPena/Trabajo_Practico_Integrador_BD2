## EXPERIMENTO Espera por Bloqueo (Read Committed vs. Repeatable Read)

### Caso 1: Nivel por Defecto (`Read Committed`)

#### Orden de Ejecución Intercalado
1. **[Sesión A]** `BEGIN;`
2. **[Sesión A]** `UPDATE producto SET precio = precio * 1.10 WHERE id_producto = 1;`
   - *Salida:* `UPDATE 1`
3. **[Sesión B]** `BEGIN;`
4. **[Sesión B]** `SELECT precio FROM producto WHERE id_producto = 1;`
   ```text
    precio  
   ---------
   2420.00
   ```
5. **[Sesión B]** `SELECT precio FROM producto WHERE id_producto = 1;`
   ```text
    precio  
   ---------
   2420.00
   ```
6. **[Sesión A]** `COMMIT;`
7. **[Sesión B]** `COMMIT;`



---

### Caso 2: Nivel `Repeatable Read`

#### Orden de Ejecución Intercalado
1. **[Sesión B]** `BEGIN ISOLATION LEVEL REPEATABLE READ;`
2. **[Sesión B]** `SELECT precio FROM producto WHERE id_producto = 1;`
   ```text
    precio  
   ---------
   2400.00
   (1 row)
   ```
3. **[Sesión A]** `BEGIN;`
4. **[Sesión A]** `UPDATE producto SET precio = precio * 1.10 WHERE id_producto = 1;`
   - *Salida:* `UPDATE 1`
5. **[Sesión A]** `COMMIT;`
6. **[Sesión B]** `SELECT precio FROM producto WHERE id_producto = 1;`
   ```text
    precio  
   ---------
   2400.00
   (1 row)
   ```
7. **[Sesión B]** `COMMIT;`


--

### EXPLICAION DE EJECUCION DE LA IA

Caso 1 (Read Committed)
- Qué pasó: A toma el lock de escritura de la fila (UPDATE sobre producto 1, sin commit). B lee la misma fila dos veces y ve el mismo valor (2420) porque A no commiteó todavía: los SELECT no esperan por locks (MVCC) ni ven datos sin commit. A commitea después de las lecturas de B, así que B nunca observa el cambio → en este intercalado no se manifiesta ninguna anomalía.
- Qué lo evitaría: Para B no hay nada que evitar si solo lee (MVCC ya lo resuelve). La "espera" real existe solo si B escribiera la misma fila: esperaría bajo cualquier nivel. Para que B vea valores estables aunque A commitee entre sus dos lecturas → REPEATABLE READ.


Caso 2 (Repeatable Read)
- Qué pasó: B fija su snapshot en el primer SELECT (2400). A modifica el precio (2400 × 1.1 = 2640) y commitea. B relee la misma fila y sigue viendo 2400 porque su snapshot quedó congelado al inicio de la transacción -> comportamiento correcto de RR, sin lectura no repetible.
- Qué lo evitaría: REPEATABLE READ o SERIALIZABLE, que congelan la snapshot durante toda la transacción. Nota: si B intentara escribir basándose en ese valor viejo, RR lanzaría un error de serialización (40001).

--
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
### EXPLICAION DE EJECUCION DE LA IA
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
### EXPLICAION DE EJECUCION DE LA IA

Caso 1 (Read Committed)
- Qué pasó: B lee stock=240; A descuenta 5 y commitea (queda 235); B relee y ve 235 → LECTURA NO REPETIBLE. En RC cada sentencia abre un snapshot nuevo y ve el último commit.
- Qué lo evitaría: REPEATABLE READ (la segunda lectura vuelve a dar 240) o SERIALIZABLE. Alternativa clásica de bloqueo: locks compartidos de lectura mantenidos hasta el commit (tipo SELECT ... FOR SHARE).

Caso 2 (Repeatable Read)
- Qué pasó: B lee 235; A descuenta a 230 y commitea; B relee y sigue viendo 235 (misma snapshot) → comportamiento correcto, sin anomalía.
- Qué lo evitaría: Ya está prevenido; solo hay que no bajar a RC. Nota: si B intentara ahora escribir basado en ese valor viejo, RR lanzaría un error de serialización (40001), evitando también la pérdida de actualización.
---
