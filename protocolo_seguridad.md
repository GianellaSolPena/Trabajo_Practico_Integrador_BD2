# Protocolo de Seguridad y Entorno de Trabajo

Este documento establece las directivas obligatorias para la ejecución de cualquier script DDL o DML sobre la base de datos del proyecto.

## 1. Copia de Desarrollo (Copia)

Nunca se modifica la base de datos principal o de plantilla directamente. Todas las pruebas y tareas de desarrollo se ejecutan obligatoriamente sobre una base de datos copia (`copia_trabajo`) para aislar el entorno.

**Comando de creación de la copia de trabajo:**

```bash
createdb -U postgres -T "Food Store" "copia_trabajo"
```

## 2. Prueba en Transacción (Transacción)

Todo script que inserte, modifique o elimine datos o estructuras debe correr primero dentro de una transacción explícita. Esto permite verificar las filas afectadas y los mensajes del motor antes de persistir cualquier cambio.

**Estructura del bloque de prueba:**

```sql
BEGIN;

-- Script DDL o DML a probar (ej. inserciones de prueba, UPDATE o ALTER TABLE)
-- Consultas SELECT de verificación para inspeccionar el efecto real

ROLLBACK; -- Se revierte tras verificar la prueba
-- COMMIT; -- Solo se ejecuta si la verificación fue exitosa y se desea persistir
```

## 3. Respaldo previo a DDL (Respaldo)

Antes de realizar cualquier cambio estructural sobre la base de datos (`ALTER TABLE`, `DROP`, `CREATE TRIGGER`), se debe generar un respaldo completo de la copia de trabajo para poder retornar a un estado seguro en caso de error grave.

**Comando de respaldo (Backup):**

```bash
pg_dump -U postgres -F c -b -v -f "./db/backups/backup_pre_cambio_$(date +%Y%m%d_%H%M%S).backup" "copia_trabajo"
```

**Comando de restauración (en caso de falla destructiva):**

```bash
pg_restore -U postgres -d "copia_trabajo" --clean "./db/backups/backup_pre_cambio_$(date +%Y%m%d_%H%M%S).backup"
```

## 4. Orden de ejecución de los scripts

1. `db/schema.sql` — crea los tipos (ENUM), tablas, constraints y triggers con sus nombres definitivos.
2. `db/indices.sql` — crea todos los índices de la base (única fuente de verdad para índices).
3. `db/restricciones.sql` — re-aplica las restricciones de integridad sobre una base ya existente (opcional sobre esquema recién creado).
4. `db/registros_foodstore.sql` — puebla la base con datos masivos de prueba.