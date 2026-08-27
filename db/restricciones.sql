-- ============================================
-- RESTRICCIONES DE INTEGRIDAD
-- Base: Food Store Restaurada (copia de trabajo)
-- ============================================

-- 1) PRODUCTO: reemplazo del CHECK de precio
--    Exige precio > 0 (antes permitía 0). Se elimina el CHECK
--    autogenerado del schema original y se recrea con nombre explícito.
ALTER TABLE producto
    DROP CONSTRAINT IF EXISTS producto_precio_check;

ALTER TABLE producto
    DROP CONSTRAINT IF EXISTS chk_producto_precio_positivo;

ALTER TABLE producto
    ADD CONSTRAINT chk_producto_precio_positivo
    CHECK (precio > 0);


-- 2) PEDIDO: impedir fecha_pedido anterior a CURRENT_DATE
--    Se usa un BEFORE INSERT OR UPDATE en lugar de un CHECK porque
--    CURRENT_DATE es un valor móvil: un CHECK dejaría inválidas las
--    filas al pasar el día y rompería cualquier UPDATE posterior de la
--    misma fila. El trigger valida únicamente en el momento de escribir.
DROP TRIGGER IF EXISTS trg_validar_fecha_pedido ON pedido;

CREATE OR REPLACE FUNCTION fn_validar_fecha_pedido()
RETURNS trigger AS $$
BEGIN
    IF NEW.fecha_pedido::date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Fecha de pedido (%) no puede ser anterior a la fecha actual (%)',
            NEW.fecha_pedido, CURRENT_DATE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pedido_fecha_no_pasada
    BEFORE INSERT OR UPDATE ON pedido
    FOR EACH ROW EXECUTE FUNCTION fn_validar_fecha_pedido();


-- 3) CLIENTE: username único
--    El username nunca se repite, aunque el cliente esté eliminado
--    lógicamente (deleted_at set): el UNIQUE es total sobre la columna.
ALTER TABLE cliente
    ADD CONSTRAINT chk_username_unico UNIQUE (username);