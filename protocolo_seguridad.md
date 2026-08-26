# Protocolo de Seguridad y Entorno de Trabajo - TP2

## 1. Copia de Desarrollo
- La base de datos de producción/plantilla nunca se modifica directamente.
- Se trabaja sobre una base de datos copia para pruebas.

## 2. Prueba en Transacción
- Todo script DDL o DML generado o modificado se ejecuta primero dentro de una transacción de prueba:
  ```sql
  BEGIN;
  -- Script o prueba a realizar
  ROLLBACK; -- Para revertir tras verificar, o COMMIT si fue exitoso