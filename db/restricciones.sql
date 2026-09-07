-- ============================================
-- RESTRICCIONES DE INTEGRIDAD
-- Base: Food Store (copia de trabajo)
-- Idempotente: seguro de re-aplicar.
-- ============================================


-- ============================================
-- 1) PRODUCTO: reemplazo del CHECK de precio
--    Exige precio > 0 (antes permitía 0). Se elimina cualquier CHECK
--    previo sobre la columna y se crea con nombre explícito.
-- ============================================
ALTER TABLE producto
    DROP CONSTRAINT IF EXISTS chk_producto_precio_positivo;

ALTER TABLE producto
    DROP CONSTRAINT IF EXISTS producto_precio_check;

ALTER TABLE producto
    DROP CONSTRAINT IF EXISTS producto_precio_positivo;

ALTER TABLE producto
    ADD CONSTRAINT chk_producto_precio_positivo
    CHECK (precio > 0);


-- ============================================
-- 2) PEDIDO: impedir fecha posterior a CURRENT_DATE
--    Requirement: chk_pedido_fecha_no_pasada.
--    Se usa un BEFORE INSERT OR UPDATE en lugar de un CHECK.
--    Por qué trigger (y no CHECK):
--      CURRENT_DATE es un valor móvil. Un CHECK se evalúa contra cada
--      fila: al pasar el día un CHECK dejaría inválidas todas las filas
--      (quédate con la fecha del día correcto), y cualquier UPDATE
--      posterior fallaría aunque no toque la fecha. El trigger, en
--      cambio, valida únicamente en el momento de escribir
--      (INSERT/UPDATE), que es el único punto donde tiene sentido
--      impedir una fecha futura. Por eso la lógica vive en un trigger.
--    NOTA: esta versión impide fechas futuras (fecha > CURRENT_DATE),
--    permitiendo pedidos históricos ya pasados.
-- ============================================
DROP TRIGGER IF EXISTS trg_pedido_fecha_no_pasada ON pedido;

CREATE OR REPLACE FUNCTION fn_validar_fecha_pedido()
RETURNS trigger AS $$
BEGIN
    IF NEW.fecha::date > CURRENT_DATE THEN
        RAISE EXCEPTION 'chk_pedido_fecha_no_pasada: la fecha del pedido (%) no puede ser posterior a la fecha actual (%)',
            NEW.fecha, CURRENT_DATE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pedido_fecha_no_pasada
    BEFORE INSERT OR UPDATE ON pedido
    FOR EACH ROW EXECUTE FUNCTION fn_validar_fecha_pedido();


-- ============================================
-- 3) USUARIO: mail único
--    Requirement: chk_username_unico (renombrada como chk_mail_unico).
--    La unicidad recae sobre la columna mail (lo que identifica al
--    usuario): ningún usuario comparte mail, incluso si uno está
--    eliminado lógicamente (deleted_at set). El UNIQUE es total sobre
--    la columna.
-- ============================================
ALTER TABLE usuario
    DROP CONSTRAINT IF EXISTS chk_username_unico;

ALTER TABLE usuario
    DROP CONSTRAINT IF EXISTS chk_mail_unico;

ALTER TABLE usuario
    DROP CONSTRAINT IF EXISTS usuario_mail_key;

ALTER TABLE usuario
    ADD CONSTRAINT chk_mail_unico UNIQUE (mail);


-- ============================================
-- 4) PEDIDO: transiciones de estado válidas
--    Requirement: chk_pedido_estado.
--    Solo se admiten las transiciones:
--      PENDIENTE  -> CONFIRMADO
--      PENDIENTE  -> CANCELADO
--      CONFIRMADO -> TERMINADO
--    Cualquier otra (saltos, retrocesos, o cambios desde un estado
--    final como TERMINADO/CANCELADO) se rechaza.
--    Se usa un trigger (y no un CHECK) porque la validación compara el
--    estado NUEVO contra el estado PREVIO de la misma fila (OLD), y un
--    CHECK no puede leer el valor anterior de la fila.
-- ============================================
DROP TRIGGER IF EXISTS trg_validar_estado_pedido ON pedido;

CREATE OR REPLACE FUNCTION fn_validar_estado_pedido()
RETURNS trigger AS $$
BEGIN
    IF OLD.estado IS DISTINCT FROM NEW.estado
       AND NOT (
            (OLD.estado = 'PENDIENTE'  AND NEW.estado = 'CONFIRMADO') OR
            (OLD.estado = 'PENDIENTE'  AND NEW.estado = 'CANCELADO')  OR
            (OLD.estado = 'CONFIRMADO' AND NEW.estado = 'TERMINADO')
       )
    THEN
        RAISE EXCEPTION 'chk_pedido_estado: transición de estado inválida de % a %',
            OLD.estado, NEW.estado;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_estado_pedido
    BEFORE UPDATE OF estado ON pedido
    FOR EACH ROW EXECUTE FUNCTION fn_validar_estado_pedido();
