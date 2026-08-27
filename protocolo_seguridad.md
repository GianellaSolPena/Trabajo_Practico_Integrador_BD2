# Protocolo de Seguridad y Entorno de Trabajo - TP2

Este documento establece las directivas obligatorias para la ejecución de cualquier script DDL o DML sobre la base de datos del proyecto (creado manualmente o mediante un agente de IA como OpenCode/Kiro).

---

## 1. Copia de Desarrollo (Copia)
Nunca se modifica la base de datos principal o de plantilla directamente. Todas las pruebas y tareas de desarrollo se ejecutan obligatoriamente sobre una base de datos copia para aislar el entorno.

**Comando de creación de la copia de trabajo:**
```bash
createdb -U postgres -T "Food Store" "Food Store_dev"
```
*(Alternativa desde consola interactiva SQL):*
```sql
CREATE DATABASE "Food Store_dev" WITH TEMPLATE "Food Store";
```

---

## 2. Prueba en Transacción (Transacción)
Todo script que inserte, modifique o elimine datos o estructuras debe correr primero dentro de una transacción explícita. Esto permite verificar las filas afectadas y los mensajes del motor antes de persisitir cualquier cambio.

**Estructura del bloque de prueba:**
```sql
BEGIN;

-- Script DDL o DML a probar (ej. inserciones de prueba, UPDATE o ALTER TABLE)
-- Consultas SELECT de verificación para inspeccionar el efecto real

ROLLBACK; -- Se revierte tras verificar la prueba
-- COMMIT; -- Solo se ejecuta si la verificación fue exitosa y se desea persisitir
```

---

## 3. Respaldo previo a DDL (Respaldo)
Antes de realizar cualquier cambio estructural sobre la base de datos (`ALTER TABLE`, `DROP`, migraciones de datos), se debe generar un respaldo completo de la copia de trabajo para poder retornar a un estado seguro en caso de error grave.

**Comando de respaldo (Backup):**
```bash
pg_dump -U postgres -F c -b -v -f "./backups/food_store_dev.backup" "Food Store_dev"
```

**Comando de restauración (en caso de falla destructiva):**
```bash
pg_restore -U postgres -d "Food Store_dev" --clean "./backups/food_store_dev.backup"