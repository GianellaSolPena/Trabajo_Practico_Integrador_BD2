-- ============================================
-- RESTRICCIONES DE INTEGRIDAD - Food Store
-- ============================================

-- Ajustar datos existentes para cumplir la
-- nueva restriccion de contrasena (mayuscula)

UPDATE cliente SET contrasena = 'Pass1234'  WHERE username = 'maria_garcia';
UPDATE cliente SET contrasena = 'Segura5678' WHERE username = 'juan_lopez';
UPDATE cliente SET contrasena = 'Carl0s_pass' WHERE username = 'carlos_silva';

-- ============================================
-- 1) CHECK: precio estrictamente mayor a 0
-- ============================================

ALTER TABLE producto
    DROP CONSTRAINT IF EXISTS producto_precio_check;

ALTER TABLE producto
    ADD CONSTRAINT producto_precio_check
    CHECK (precio > 0);

-- ============================================
-- 2) TRIGGER: fecha_pedido >= CURRENT_DATE
-- ============================================

CREATE OR REPLACE FUNCTION fn_validar_fecha_pedido()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.fecha_pedido::date < CURRENT_DATE THEN
        RAISE EXCEPTION 'La fecha del pedido no puede ser anterior a la fecha actual (%).', CURRENT_DATE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validar_fecha_pedido ON pedido;

CREATE TRIGGER trg_validar_fecha_pedido
    BEFORE INSERT OR UPDATE ON pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_fecha_pedido();

-- ============================================
-- 3) CHECK: contrasena > 4 chars y al menos
--    una letra mayuscula
-- ============================================

ALTER TABLE cliente
    DROP CONSTRAINT IF EXISTS chk_contrasena_segura;

ALTER TABLE cliente
    ADD CONSTRAINT chk_contrasena_segura
    CHECK (
        LENGTH(contrasena) > 4
        AND contrasena ~ '[A-Z]'
    );

-- ============================================
-- PRUEBAS (BEGIN ... ROLLBACK)
-- ============================================

BEGIN;

-- 1) PRUEBA CHECK precio > 0

-- OK: precio valido
SAVEPOINT sp1;
INSERT INTO producto (nombre, precio, stock, id_categoria)
    VALUES ('Jugo de naranja 1L', 2.50, 100, 1);
SELECT 'OK: precio valido (2.50)' AS resultado;
ROLLBACK TO sp1;

-- OK: precio mayor a 0
SAVEPOINT sp2;
INSERT INTO producto (nombre, precio, stock, id_categoria)
    VALUES ('Galletitas surtidas', 0.01, 200, 2);
SELECT 'OK: precio valido (0.01)' AS resultado;
ROLLBACK TO sp2;

-- FALLO: precio igual a 0
SAVEPOINT sp3;
INSERT INTO producto (nombre, precio, stock, id_categoria)
    VALUES ('Producto gratis', 0.00, 50, 1);
SELECT 'OK: precio 0 aceptado (NO DEBERIA)' AS resultado;
ROLLBACK TO sp3;
SELECT 'FALLO: precio igual a 0 rechazado correctamente' AS resultado;

-- FALLO: precio negativo
SAVEPOINT sp4;
INSERT INTO producto (nombre, precio, stock, id_categoria)
    VALUES ('Producto negativo', -5.00, 10, 1);
SELECT 'OK: precio negativo aceptado (NO DEBERIA)' AS resultado;
ROLLBACK TO sp4;
SELECT 'FALLO: precio negativo rechazado correctamente' AS resultado;

-- 2) PRUEBA TRIGGER fecha_pedido >= CURRENT_DATE

-- OK: fecha actual
SAVEPOINT sp5;
INSERT INTO pedido (fecha_pedido, forma_de_pago, id_cliente)
    VALUES (NOW(), 'EFECTIVO', 1);
SELECT 'OK: fecha actual aceptada' AS resultado;
ROLLBACK TO sp5;

-- FALLO: fecha en el pasado
SAVEPOINT sp6;
INSERT INTO pedido (fecha_pedido, forma_de_pago, id_cliente)
    VALUES ('2020-01-01 10:00:00-04', 'CREDITO', 2);
SELECT 'OK: fecha pasada aceptada (NO DEBERIA)' AS resultado;
ROLLBACK TO sp6;
SELECT 'FALLO: fecha pasada rechazada correctamente' AS resultado;

-- 3) PRUEBA CHECK contrasena segura

-- OK: cumple longitud y tiene mayuscula
SAVEPOINT sp7;
INSERT INTO cliente (username, email, contrasena)
    VALUES ('test_user1', 'test1@email.com', 'Abcde1');
SELECT 'OK: contrasena valida aceptada' AS resultado;
ROLLBACK TO sp7;

-- OK: contrasena larga con mayuscula
SAVEPOINT sp8;
INSERT INTO cliente (username, email, contrasena)
    VALUES ('test_user2', 'test2@email.com', 'Segura2024!');
SELECT 'OK: contrasena larga aceptada' AS resultado;
ROLLBACK TO sp8;

-- FALLO: longitud <= 4
SAVEPOINT sp9;
INSERT INTO cliente (username, email, contrasena)
    VALUES ('test_user3', 'test3@email.com', 'Ab1');
SELECT 'OK: contrasena corta aceptada (NO DEBERIA)' AS resultado;
ROLLBACK TO sp9;
SELECT 'FALLO: contrasena corta rechazada correctamente' AS resultado;

-- FALLO: sin letra mayuscula
SAVEPOINT sp10;
INSERT INTO cliente (username, email, contrasena)
    VALUES ('test_user4', 'test4@email.com', 'abcdef');
SELECT 'OK: sin mayuscula aceptada (NO DEBERIA)' AS resultado;
ROLLBACK TO sp10;
SELECT 'FALLO: sin mayuscula rechazada correctamente' AS resultado;

-- FALLO: longitud <= 4 y sin mayuscula
SAVEPOINT sp11;
INSERT INTO cliente (username, email, contrasena)
    VALUES ('test_user5', 'test5@email.com', 'ab1');
SELECT 'OK: corta y sin mayuscula aceptada (NO DEBERIA)' AS resultado;
ROLLBACK TO sp11;
SELECT 'FALLO: corta y sin mayuscula rechazada correctamente' AS resultado;

ROLLBACK;
