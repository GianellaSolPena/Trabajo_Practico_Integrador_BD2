# Plan Aplicado — Unificación de `schema.sql`, `indices.sql` y `restricciones.sql`

Fecha: 2026-09-12
Motor: PostgreSQL  —  Base de prueba: `copia_trabajo`

## 1. Contexto

Se detectaron inconsistencias entre los tres archivos de DDL del proyecto que
impedían ejecutarlos de forma encadenada y predecible:

1. `schema.sql` no incluía el trigger `trg_validar_estado_pedido` (existía solo en `restricciones.sql`).
2. `schema.sql` creaba índices que luego `indices.sql` re-creaba de forma distinta (conflicto de doble fuente de verdad).
3. Varios CHECK y la columna `mail` tenían constraints sin nombre explícito (recibían nombres generados por el motor, p. ej. `usuario_mail_key`).
4. Faltaba `chk_detalle_pedido_precio_unitario_no_negativo` (exigido en AGENTS.md, ausente en ambos archivos).
5. `indices.sql` marcaba `idx_pedido_usuario` e `idx_producto_categoria` como parciales cuando AGENTS.md no los marca como parciales.
6. `restricciones.sql` usaba la nomenclatura `chk_username_unico` vs el resto del esquema (`chk_<tabla>_<columna>`).
7. `protocolo_seguridad.md` conservaba instrucciones de trabajo de la IA sin depurar.
8. El experimento de "espera por bloqueo" del informe de concurrencia no reproducía el fenómeno (la sesión B solo leía).

## 2. Decisiones tomadas

| Decisión | Opción elegida |
|---|---|
| Fuente de verdad de índices | `db/indices.sql` (única; `schema.sql` no crea índices) |
| Unicidad del mail | `chk_mail_unico` (patrón `chk_<tabla>_<columna>`; la spec lo pedía como `chk_username_unico`) |
| `restricciones.sql` | Se mantiene como script de re-aplicación idempotente, alineado 1:1 con `schema.sql` |
| Copia de trabajo | Nombre unificado: `copia_trabajo` |
| Índices `idx_pedido_usuario` e `idx_producto_categoria` | Índices completos (sin filtro parcial) |
| Experimento de espera por bloqueo | Se documenta la secuencia corregida (B ejecuta `UPDATE` sobre la fila bloqueada), sin re-ejecución en vivo |

## 3. Cambios aplicados por archivo

### `db/schema.sql`
- `usuario.mail`: el `UNIQUE` anónimo ahora es `CONSTRAINT chk_mail_unico UNIQUE` (elimina el auto-generado `usuario_mail_key`).
- `producto.stock`: CHECK con nombre explícito `chk_producto_stock_no_negativo`.
- `pedido`: se añadió `fn_validar_estado_pedido()` + `trg_validar_estado_pedido` (`BEFORE UPDATE OF estado`), absorbidos de `restricciones.sql`.
- `detalle_pedido`: CHECK de `cantidad` con nombre `chk_detalle_pedido_cantidad_positiva`; se agregó `chk_detalle_pedido_precio_unitario_no_negativo` sobre `precio_unitario`.
- Mensaje de `fn_validar_fecha_pedido` unificado con el de `restricciones.sql` (incluye el nombre `chk_pedido_fecha_no_pasada`).
- Se eliminó la sección de índices (los índices viven solo en `db/indices.sql`).

### `db/indices.sql`
- Se agregó `idx_producto_nombre_vig` (parcial, `WHERE deleted_at IS NULL`), que antes vivía solo en `schema.sql`.
- `idx_pedido_usuario` e `idx_producto_categoria` pasaron a ser índices completos (sin `WHERE deleted_at IS NULL`).
- Se mantienen parciales: `idx_producto_nombre_vig`, `idx_producto_categoria_precio`, `idx_producto_precio`, `idx_pedido_usuario_fecha`.
- Se mantienen completos: `idx_detalle_pedido_id_pedido`, `idx_detalle_pedido_id_producto`.
- Todo sigue el patrón `DROP INDEX IF EXISTS` + `CREATE INDEX` (idempotente).

### `db/restricciones.sql`
- Se actualizó la cabecera para documentar el orden de ejecución y que es la capa de re-aplicación de `schema.sql`.
- La sección 3 documenta el nombre definitivo `chk_mail_unico` (la spec lo pedía como `chk_username_unico`).
- El resto de la lógica coincide con lo absorbido en `schema.sql`.

### `protocolo_seguridad.md`
- Se eliminó la sección "Pasos a seguir ahora" (instructivos dirigidos a la IA para copiar/guardar/commitear).
- Se corrigió el Markdown roto (bloque `pg_restore` sin cierre, marcas `---` sueltas, líneas vacías).
- Se unificó el nombre de la base copia a `copia_trabajo` en todos los comandos.
- Se agregó la sección "Orden de ejecución de los scripts".

### `AGENTS.md`
- Lista de tablas actualizada con los nombres explícitos de constraints (`chk_mail_unico`, `chk_producto_stock_no_negativo`, `chk_detalle_pedido_cantidad_positiva`, `chk_detalle_pedido_precio_unitario_no_negativo`).
- Índices: `db/indices.sql` queda declarado como única fuente de verdad; `schema.sql` ya no crea índices.
- Se documentó el orden de ejecución (schema → indices → restricciones → registros).

### `docs/DUIA_restricciones.md`
- La declaración refleja el nombre final `chk_mail_unico` (con nota sobre el nombre original de la spec).

### `docs/tp2_informe_concurrencia.md`
- El experimento de espera por bloqueo ahora reproduce el fenómeno: la sesión B ejecuta un `UPDATE` sobre la misma fila bloqueada por A y queda en espera hasta el `COMMIT`/`ROLLBACK` de A.
- Se añadió una autocrítica explicando que la versión previa (solo `SELECT`s) no reproducía el fenómeno.
- Se corrigieron los títulos "EXPLICAION DE EJECUCION DE LA IA" por "Explicación de la ejecución (IA)".

### Repositorio
- Se reubicaron `schema.sql` y `registros_foodstore.sql` en `db/` (antes en la raíz) y se renombraron los docs de TP2; quedaron trackeados.
- Se eliminaron de Git los `.DS_Store` y se agregaron a `.gitignore`.

## 4. Verificación realizada (según protocolo de seguridad)

1. Se creó la base `copia_trabajo` y se generó respaldo previo con `pg_dump` en `db/backups/`.
2. Se ejecutaron en orden `db/schema.sql` → `db/indices.sql` → `db/restricciones.sql` sin errores.
3. **Idempotencia:** se re-ejecutaron `indices.sql` y `restricciones.sql` sin errores (los 8 índices se recrearon; los triggers/constraints se re-aplicaron).
4. **Pruebas de restricciones** (dentro de `BEGIN; ... ROLLBACK;`), todas verificadas:
   - `chk_producto_precio_positivo` rechaza precio 0.
   - `chk_producto_stock_no_negativo` rechaza stock -1.
   - `chk_mail_unico` rechaza mail duplicado.
   - `chk_mail_formato` rechaza mail sin arroba.
   - `trg_pedido_fecha_no_pasada` rechaza fecha futura.
   - `trg_validar_estado_pedido` rechaza `PENDIENTE → TERMINADO` y permite `PENDIENTE → CONFIRMADO → TERMINADO`.
   - `chk_detalle_pedido_cantidad_positiva` rechaza cantidad 0.
   - `trg_subtotal` completa `subtotal` (3 x 100 = 300.00).
5. **Objetos finales** verificados con consultas a catálogo:
   - Constraints: `chk_mail_unico`, `chk_mail_formato`, `chk_producto_precio_positivo`, `chk_producto_stock_no_negativo`, `chk_detalle_pedido_cantidad_positiva`, `chk_detalle_pedido_precio_unitario_no_negativo`.
   - Triggers (3): `trg_pedido_fecha_no_pasada`, `trg_validar_estado_pedido`, `trg_subtotal`.
   - Índices (8): `idx_pedido_usuario`, `idx_producto_categoria`, `idx_producto_nombre_vig`, `idx_producto_categoria_precio`, `idx_producto_precio`, `idx_pedido_usuario_fecha`, `idx_detalle_pedido_id_pedido`, `idx_detalle_pedido_id_producto`.

## 5. Estado final

El conjunto de scripts es ejecutable de forma encadenada y consistente:

```
db/schema.sql  →  db/indices.sql  →  db/restricciones.sql  →  db/registros_foodstore.sql
```

`db/registros_foodstore.sql` quedó fuera del alcance de este plan (por decisión del usuario).