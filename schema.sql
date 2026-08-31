
-- ENUM FORMA DE PAGO

CREATE TYPE forma_pago AS ENUM (
    'EFECTIVO',
    'CREDITO',
    'DEBITO',
    'TRANSFERENCIA',
    'TARJETA'
);

-- ENUM ESTADO DE PEDIDO
CREATE TYPE estado_pedido AS ENUM (
    'PENDIENTE',
    'CONFIRMADO',
    'TERMINADO',
    'CANCELADO'
);



-- USUARIO


CREATE TABLE usuario (
    id_usuario BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    mail VARCHAR(100) NOT NULL UNIQUE,
    celular VARCHAR(20),
    contrasena VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT chk_mail_formato
        CHECK (mail LIKE '%@%.%')
);



-- CATEGORIA


CREATE TABLE categoria (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);



-- PRODUCTO

CREATE TABLE producto (
    id_producto BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    precio DECIMAL(10, 2) NOT NULL
        CONSTRAINT chk_producto_precio_positivo
        CHECK (precio > 0),
    descripcion VARCHAR(250),
    stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),

    categoria_id BIGINT NOT NULL
        REFERENCES categoria(id_categoria)
        ON DELETE RESTRICT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);



-- PEDIDO


CREATE TABLE pedido (
    id_pedido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
    estado estado_pedido NOT NULL DEFAULT 'PENDIENTE',
    forma_pago forma_pago NOT NULL DEFAULT 'EFECTIVO',

    usuario_id BIGINT NOT NULL
        REFERENCES usuario(id_usuario)
        ON DELETE RESTRICT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);


-- ============================================
-- TRIGGER VALIDACIÓN FECHA PEDIDO
-- ============================================
-- Impide que fecha sea anterior a CURRENT_DATE. Se usa un
-- trigger (y no un CHECK) porque CURRENT_DATE es un valor móvil: un
-- CHECK invalidaría las filas al pasar el día y rompería cualquier
-- UPDATE posterior de la misma fila.

CREATE OR REPLACE FUNCTION fn_validar_fecha_pedido()
RETURNS trigger AS $$
BEGIN
    IF NEW.fecha::date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Fecha de pedido (%) no puede ser anterior a la fecha actual (%)',
            NEW.fecha, CURRENT_DATE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pedido_fecha_no_pasada
    BEFORE INSERT OR UPDATE ON pedido
    FOR EACH ROW EXECUTE FUNCTION fn_validar_fecha_pedido();



-- DETALLE PEDIDO

CREATE TABLE detalle_pedido (
    pedido_id BIGINT NOT NULL
        REFERENCES pedido(id_pedido)
        ON DELETE CASCADE,

    producto_id BIGINT NOT NULL
        REFERENCES producto(id_producto)
        ON DELETE RESTRICT,

    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (pedido_id, producto_id),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);


-- ============================================
-- TRIGGER SUBTOTAL DETALLE PEDIDO
-- ============================================
-- Completa precio_unitario (desde el producto) y subtotal
-- (cantidad * precio_unitario) automáticamente al insertar o actualizar.

CREATE OR REPLACE FUNCTION fn_completar_subtotal()
RETURNS trigger AS $$
BEGIN
    NEW.precio_unitario := (
        SELECT precio FROM producto WHERE id_producto = NEW.producto_id
    );
    NEW.subtotal := NEW.cantidad * NEW.precio_unitario;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_subtotal
    BEFORE INSERT OR UPDATE ON detalle_pedido
    FOR EACH ROW EXECUTE FUNCTION fn_completar_subtotal();


-- ============================================
-- ÍNDICES
-- ============================================

CREATE INDEX idx_pedido_usuario
    ON pedido(usuario_id);

CREATE INDEX idx_producto_categoria
    ON producto(categoria_id);