# AGENTS.md - Base de Datos II

## Motor
PostgreSQL.

## Reglas del Repositorio
- Toda modificación DDL/DML debe probarse primero dentro de una transacción (`BEGIN; ... ROLLBACK;`).
- Las pruebas se realizan sobre la base de datos copia (`copia_trabajo`), nunca sobre la base original.
- Usar palabras clave SQL en mayúsculas.
- Antes de un cambio estructural (ALTER, DROP, CREATE TRIGGER), generar respaldo con `pg_dump`.

## Esquema

### Patrón general
Todas las tablas usan borrado lógico: `deleted_at TIMESTAMPTZ` (NULL = activo, con fecha = eliminado).
Todas las tablas tienen `created_at` y `updated_at` (TIMESTAMPTZ).
Las PK son `BIGINT GENERATED ALWAYS AS IDENTITY`, con nombre `id_<tabla>`.

### Tipos ENUM
- `forma_pago`: EFECTIVO, CREDITO, DEBITO, TRANSFERENCIA, TARJETA.
- `estado_pedido`: PENDIENTE, CONFIRMADO, TERMINADO, CANCELADO.

### Tablas
- **usuario** (`id_usuario`): nombre, apellido, mail (`UNIQUE` → `chk_mail_unico`, formato validado por CHECK → `chk_mail_formato`), celular, contrasena.
- **categoria** (`id_categoria`): nombre.
- **producto** (`id_producto`): nombre, precio (CHECK > 0 → `chk_producto_precio_positivo`), stock (CHECK >= 0 → `chk_producto_stock_no_negativo`), id_categoria → FK a categoria (ON DELETE RESTRICT).
- **pedido** (`id_pedido`): fecha (TIMESTAMPTZ, default now), estado (enum, default PENDIENTE), forma_pago (enum, default EFECTIVO), id_usuario → FK a usuario (ON DELETE RESTRICT). Trigger que impide fecha posterior a la actual (`trg_pedido_fecha_no_pasada`). Trigger que valida transiciones de estado (`trg_validar_estado_pedido`).
- **detalle_pedido** (PK compuesta `id_pedido, id_producto`): cantidad (CHECK > 0 → `chk_detalle_pedido_cantidad_positiva`), precio_unitario (CHECK >= 0 → `chk_detalle_pedido_precio_unitario_no_negativo`), subtotal (NOT NULL), FK a pedido (ON DELETE CASCADE) y a producto (ON DELETE RESTRICT). Trigger `trg_subtotal` completa precio_unitario y subtotal automáticamente.

### Índices
Definidos en `db/indices.sql` como única fuente de verdad (idempotente: `DROP INDEX IF EXISTS` + `CREATE`):
- `idx_pedido_usuario` sobre pedido(id_usuario) — índice completo.
- `idx_producto_categoria` sobre producto(id_categoria) — índice completo.
- `idx_producto_nombre_vig` sobre producto(nombre) partial (deleted_at IS NULL).
- `idx_producto_categoria_precio` sobre producto(id_categoria, precio DESC) partial (deleted_at IS NULL).
- `idx_producto_precio` sobre producto(precio) partial (deleted_at IS NULL).
- `idx_pedido_usuario_fecha` sobre pedido(id_usuario, fecha) partial (deleted_at IS NULL).
- `idx_detalle_pedido_id_pedido` sobre detalle_pedido(id_pedido) — índice completo.
- `idx_detalle_pedido_id_producto` sobre detalle_pedido(id_producto) — índice completo.

> **Fuente de verdad de índices:** `db/indices.sql`. `db/schema.sql` NO crea índices (solo PK/FK y constraints) para evitar divergencias entre ambos archivos.

### Orden de ejecución
1. `db/schema.sql` — tipos ENUM, tablas, constraints y triggers con sus nombres definitivos.
2. `db/indices.sql` — crea todos los índices (idempotente).
3. `db/restricciones.sql` — re-aplica las restricciones sobre una base ya existente (opcional si el esquema es nuevo).
4. `db/registros_foodstore.sql` — poblado masivo de datos de prueba (idempotente).

## Limitaciones conocidas (no garantizadas por el motor hoy)
- El stock de `producto` no se descuenta automáticamente al insertar un `detalle_pedido`.
- Se puede vender un producto o categorizar bajo una categoría que ya tiene `deleted_at` seteado (eliminada lógicamente).

## Seguridad
Respetar siempre las normas definidas en
`.kiro/steering/security-policies.md`.