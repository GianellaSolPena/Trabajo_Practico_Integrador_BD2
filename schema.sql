


-- ============================================
-- ENUM FORMA DE PAGO
-- ============================================

CREATE TYPE forma_de_pago AS ENUM (
    'EFECTIVO',
    'CREDITO',
    'DEBITO',
    'TRANSFERENCIA'
);


-- ============================================
-- CLIENTE
-- ============================================

CREATE TABLE cliente (
    id_cliente BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    contrasena VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT chk_email_formato
        CHECK (email LIKE '%@%.%'),

    CONSTRAINT chk_username_unico
        UNIQUE (username)
);


-- ============================================
-- CATEGORIA
-- ============================================

CREATE TABLE categoria (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);


-- ============================================
-- PRODUCTO
-- ============================================

CREATE TABLE producto (
    id_producto BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    precio DECIMAL(10, 2) NOT NULL
        CONSTRAINT chk_producto_precio_positivo
        CHECK (precio > 0),
    stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),

    id_categoria BIGINT NOT NULL
        REFERENCES categoria(id_categoria)
        ON DELETE RESTRICT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);


-- ============================================
-- PEDIDO
-- ============================================

CREATE TABLE pedido (
    id_pedido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_pedido TIMESTAMPTZ NOT NULL DEFAULT now(),

    forma_de_pago forma_de_pago NOT NULL DEFAULT 'EFECTIVO',

    id_cliente BIGINT NOT NULL
        REFERENCES cliente(id_cliente)
        ON DELETE RESTRICT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);


-- ============================================
-- TRIGGER VALIDACIÓN FECHA PEDIDO
-- ============================================
-- Impide que fecha_pedido sea anterior a CURRENT_DATE. Se usa un
-- trigger (y no un CHECK) porque CURRENT_DATE es un valor móvil: un
-- CHECK invalidaría las filas al pasar el día y rompería cualquier
-- UPDATE posterior de la misma fila.

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


-- ============================================
-- DETALLE PEDIDO
-- ============================================

CREATE TABLE detalle_pedido (
    id_pedido BIGINT NOT NULL
        REFERENCES pedido(id_pedido)
        ON DELETE CASCADE,

    id_producto BIGINT NOT NULL
        REFERENCES producto(id_producto)
        ON DELETE RESTRICT,

    cantidad INT NOT NULL CHECK (cantidad > 0),

    precio_unitario DECIMAL(10, 2) NOT NULL
        CHECK (precio_unitario >= 0),

    PRIMARY KEY (id_pedido, id_producto),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);


-- ============================================
-- ÍNDICES
-- ============================================

CREATE INDEX idx_pedido_cliente
    ON pedido(id_cliente);

CREATE INDEX idx_producto_categoria
    ON producto(id_categoria);