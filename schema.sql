


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
        CHECK (email LIKE '%@%.%')
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
    precio DECIMAL(10, 2) NOT NULL CHECK (precio >= 0),
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