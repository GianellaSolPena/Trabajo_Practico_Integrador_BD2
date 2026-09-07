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
- **usuario** (`id_usuario`): nombre, apellido, mail (UNIQUE, formato validado por CHECK), celular, contrasena.
- **categoria** (`id_categoria`): nombre.
- **producto** (`id_producto`): nombre, precio (CHECK > 0), stock (CHECK >= 0), id_categoria → FK a categoria (ON DELETE RESTRICT).
- **pedido** (`id_pedido`): fecha (TIMESTAMPTZ, default now), estado (enum, default PENDIENTE), forma_pago (enum, default EFECTIVO), id_usuario → FK a usuario (ON DELETE RESTRICT). Trigger que impide fecha posterior a la actual (`trg_pedido_fecha_no_pasada`). Trigger que valida transiciones de estado (`trg_validar_estado_pedido`).
- **detalle_pedido** (PK compuesta `id_pedido, id_producto`): cantidad (CHECK > 0), precio_unitario (CHECK >= 0), subtotal (NOT NULL), FK a pedido (ON DELETE CASCADE) y a producto (ON DELETE RESTRICT). Trigger `trg_subtotal` completa precio_unitario y subtotal automáticamente.

### Índices
Definidos en `db/indices.sql` y `schema.sql`:
- `idx_pedido_usuario` sobre pedido(id_usuario).
- `idx_producto_categoria` sobre producto(id_categoria).
- `idx_producto_nombre_vig` sobre producto(nombre) parcial (deleted_at IS NULL).
- `idx_producto_categoria_precio` sobre producto(id_categoria, precio DESC) parcial (deleted_at IS NULL).
- `idx_producto_precio` sobre producto(precio) parcial (deleted_at IS NULL).
- `idx_pedido_usuario_fecha` sobre pedido(id_usuario, fecha) parcial (deleted_at IS NULL).

> **Fuente de verdad de índices:** `db/indices.sql` (los índices de rendimiento) y `schema.sql` (PK/FK y `idx_producto_nombre_vig`). Ambos deben mantenerse alineados; son idempotentes para re-ejecución.

## Limitaciones conocidas (no garantizadas por el motor hoy)
- El stock de `producto` no se descuenta automáticamente al insertar un `detalle_pedido`.
- Se puede vender un producto o categorizar bajo una categoría que ya tiene `deleted_at` seteado (eliminada lógicamente).

## Seguridad
Respetar siempre las normas definidas en
`.kiro/steering/security-policies.md`.