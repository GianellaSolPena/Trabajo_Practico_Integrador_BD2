# DUIA - Documento de Uso y Integridad Acadica


---

## Herramienta utilizada :

**Herramienta**  OpenCode 
**Modelo/Proveedor** big-pickle (opencode/big-pickle) 

---

## Spec o prompt utilizado

> Necesito que crees un script SQL llamado `restricciones.sql` que agregue 3 restricciones de integridad a las tablas de mi esquema (`schema.sql`):
>
> 1) En la tabla `producto`: una restriccin CHECK que valide que el precio sea estrictamente mayor a 0.
> 2) En la tabla `pedido`: una funcin y un TRIGGER que validen que `fecha_pedido` sea mayor o igual al da actual (`CURRENT_DATE`), impidiendo fechas pasadas.
> 3) En la tabla `cliente`: una restriccin CHECK que valide que la `contrasena` tenga ms de 4 caracteres y contenga al menos una letra mayscula.
>
> El script debe seguir el protocolo de AGENTS.md: incluir la creacin de las restricciones y agregar al final inserciones de prueba (tanto vlidas como invlidas) envueltas en un bloque de transaccin `BEGIN; ... ROLLBACK;` para poder verificar que las reglas funcionen sin alterar la base de datos.

---

## Que genero

### Archivos creados

`restricciones.sql`  Script con 3 restricciones + pruebas con SAVEPOINT 

### Estructura del script generado

| Actualizacion de datos existentes | 6-8 | Ajusta contraseas para cumplir la nueva regla |

| Restriccin 1: CHECK precio | 13-17 | `ALTER TABLE producto ADD CONSTRAINT ... CHECK (precio > 0)` |
| Restriccin 2: TRIGGER fecha | 22-41 | Funcin `fn_validar_fecha_pedido()` + trigger `BEFORE INSERT OR UPDATE` |
| Restriccin 3: CHECK contrasea | 46-52 | `CHECK (LENGTH(contrasena) > 4 AND contrasena ~ '[A-Z]')` |

Pruebas con SAVEPOINT | 57-155 | 11 pruebas ( vlidas + invlidas) aisladas con `SAVEPOINT` |

---

## Que se acepto

- Las 3 restricciones se aceptaron tal cual las propuso la IA.
- La funcin del TRIGGER  para fechas pasadas.
- El uso de `SAVEPOINT` para aislar cada prueba dentro del bloque `BEGIN ... ROLLBACK`.
- El patron de probar tanto casos validos como invlidos para cada restriccin.

---

## Qu se modific o descart


| Separar la creacin de restricciones del bloque de pruebas | El CHECK de contrasea fallaba porque los datos existentes no cumplan la nueva regla. Se corrigi actualizando las contraseas existentes antes de agregar la restriccin. |
| Reemplazar `BEGIN ... ROLLBACK` simple por `SAVEPOINT` por prueba | En PostgreSQL, un `INSERT` fallido dentro de una transaccin aborta todo el bloque. Con `SAVEPOINT` cada prueba se aisl y se pudo verificar cada caso individualmente. |
| Agregar `UPDATE` de datos existentes al inicio | Las contraseas originales (`pass1234`, `segura5678`, `carl0s_pass`) no tenan mayscula y violaban la nueva restriccin. Se actualizaron a `Pass1234`, `Segura5678`, `Carl0s_pass`. |

---

## Verificacin realizada

### Resultado de las pruebas (psql)

**Restriccin 1 - CHECK precio > 0:**

| Prueba | Valor | Resultado esperado | Resultado real |
|--------|-------|-------------------|----------------|
| Precio vlido | 2.50 | Aceptado | Aceptado |
| Precio mnimo | 0.01 | Aceptado | Aceptado |
| Precio = 0 | 0.00 | Rechazado | Rechazado |
| Precio negativo | -5.00 | Rechazado | Rechazado |

**Restriccin 2 - TRIGGER fecha_pedido >= CURRENT_DATE:**

| Prueba | Valor | Resultado esperado | Resultado real |
|--------|-------|-------------------|----------------|
| Fecha actual | NOW() | Aceptada | Aceptada |
| Fecha pasada | 2020-01-01 | Rechazada | Rechazada |

**Restriccin 3 - CHECK contrasea segura:**

| Prueba | Valor | Resultado esperado | Resultado real |
|--------|-------|-------------------|----------------|
| Longitud + mayscula | Abcde1 | Aceptada | Aceptada |
| Contrasea larga | Segura2024! | Aceptada | Aceptada |
| Longitud <= 4 | Ab1 | Rechazada | Rechazada |
| Sin mayscula | abcdef | Rechazada | Rechazada |
| Corta + sin mayscula | ab1 | Rechazada | Rechazada |

### Comando ejecutado

```bash
psql -d "Food Store" -f restricciones.sql
```

### Estado final

- Las 3 restricciones quedaron aplicadas en la base de datos.
- El `ROLLBACK` final deshizo todas las inserciones de prueba.
- Los datos originales de la base permanecen intactos (las contraseas s se actualizaron porque estn fuera del bloque `BEGIN ... ROLLBACK`).
