## Herramienta 
Opencode

## Spec o prompt utilizado
Necesito que crees un script SQL llamado `restricciones.sql` que agregue restricciones  de integridad a mi esquema (ver AGENTS.md para convenciones), con nombre explícito en  cada constraint:

1) En `producto`: reemplazá el CHECK existente de `precio` por uno llamado  chk_producto_precio_positivo que exija precio > 0 (no >= 0).

2) En `pedido`: una restricción llamada chk_pedido_fecha_no_pasada que impida que  fecha_pedido sean posteriores al CURRENT_DATE. Evaluá si conviene CHECK o trigger y  explicame por qué elegiste esa opción.

3) En `usuario`: una restriccion llamada chk_username_unico que garantice el username no serepita entre usuarios.

## Que genero
-- 1) producto: reemplazar CHECK de precio
ALTER TABLE producto
    DROP CONSTRAINT IF EXISTS producto_precio_check;
ALTER TABLE producto
    DROP CONSTRAINT IF EXISTS chk_producto_precio_positivo;
ALTER TABLE producto
    ADD CONSTRAINT chk_producto_precio_positivo CHECK (precio > 0);

-- 2) pedido: impedir fecha posterior a CURRENT_DATE (trigger)
DROP TRIGGER IF EXISTS trg_pedido_fecha_no_pasada ON pedido;

CREATE OR REPLACE FUNCTION fn_validar_fecha_pedido()
RETURNS trigger AS $$
BEGIN
    IF NEW.fecha::date > CURRENT_DATE THEN
        RAISE EXCEPTION 'Fecha de pedido (%) no puede ser posterior a hoy (%)',
            NEW.fecha, CURRENT_DATE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pedido_fecha_no_pasada
    BEFORE INSERT OR UPDATE ON pedido
    FOR EACH ROW EXECUTE FUNCTION fn_validar_fecha_pedido();

-- 3) usuario: mail único (nunca reutilizable, aun con borrado lógico)
ALTER TABLE usuario
    ADD CONSTRAINT chk_username_unico UNIQUE (mail);


## Que se acepto

Se aceptó el 100% de la propuesta generada por OpenCode en el archivo restricciones.sql: la restricción chk_producto_precio_positivo (CHECK (precio > 0)), la función y el trigger trg_pedido_fecha_no_pasada para validar la fecha de los pedidos, y la restricción chk_username_unico (UNIQUE) para la tabla usuario.

## Que se modifico 

Ninguno. Se revisó el código propuesto mediante git diff y se validó en una transacción de prueba (BEGIN; ... ROLLBACK;). Dado que el script generado cumplía correctamente con todos los requisitos de la spec y respetaba la sintaxis de PostgreSQL, no se realizaron modificaciones manuales

## Verificacion realizada

Se realizó un respaldo con pg_dump y se probó en Food Store Restaurada con BEGIN; ... ROLLBACK;. Se ejecutaron consultas INSERT con precio 0, fecha pasada y username duplicado; el motor de PostgreSQL rechazó cada operación lanzando las excepciones correspondiente 