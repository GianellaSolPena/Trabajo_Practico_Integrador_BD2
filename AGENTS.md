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
- `forma_de_pago`: EFECTIVO, CREDITO, DEBITO, TRANSFERENCIA.

### Tablas
- **cliente** (`id_cliente`): username, email (UNIQUE, formato validado por CHECK), contrasena.
- **categoria** (`id_categoria`): nombre.
- **producto** (`id_producto`): nombre, precio (CHECK >= 0), stock (CHECK >= 0), `id_categoria` → FK a categoria (ON DELETE RESTRICT).
- **pedido** (`id_pedido`): fecha_pedido, forma_de_pago (enum, default EFECTIVO), `id_cliente` → FK a cliente (ON DELETE RESTRICT).
- **detalle_pedido** (PK compuesta `id_pedido, id_producto`): cantidad (CHECK > 0), precio_unitario (CHECK >= 0), FK a pedido (ON DELETE CASCADE) y a producto (ON DELETE RESTRICT).

### Índices
`idx_pedido_cliente` sobre pedido(id_cliente), `idx_producto_categoria` sobre producto(id_categoria).

## Limitaciones conocidas (no garantizadas por el motor hoy)
- El stock de `producto` no se descuenta automáticamente al insertar un `detalle_pedido`.
- Se puede vender un producto o categorizar bajo una categoría que ya tiene `deleted_at` seteado (eliminada lógicamente).