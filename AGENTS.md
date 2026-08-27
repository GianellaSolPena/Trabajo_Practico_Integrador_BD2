# AGENTS.md - Base de Datos II

## Reglas del Repositorio
- Toda modificación DDL/DML debe probarse primero dentro de una transacción (`BEGIN; ... ROLLBACK;`).
- Las pruebas se realizan sobre la base de datos copia.
- Usar palabras clave SQL en mayúsculas[cite: 2].