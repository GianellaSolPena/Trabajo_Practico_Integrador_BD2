
DROP INDEX IF EXISTS idx_producto_nombre_vig;

CREATE INDEX idx_producto_nombre_vig
    ON producto(nombre)
WHERE deleted_at IS NULL;

DROP INDEX IF EXISTS idx_producto_categoria_precio;

CREATE INDEX idx_producto_categoria_precio
    ON producto(id_categoria, precio DESC)
WHERE deleted_at IS NULL;

DROP INDEX IF EXISTS idx_producto_precio;

CREATE INDEX idx_producto_precio
    ON producto(precio)
WHERE deleted_at IS NULL;

DROP INDEX IF EXISTS idx_pedido_usuario_fecha;

CREATE INDEX idx_pedido_usuario_fecha
    ON pedido(id_usuario, fecha)
WHERE deleted_at IS NULL;

DROP INDEX IF EXISTS idx_pedido_usuario;

CREATE INDEX idx_pedido_usuario
    ON pedido(id_usuario);

DROP INDEX IF EXISTS idx_detalle_pedido_id_pedido;

CREATE INDEX idx_detalle_pedido_id_pedido
    ON detalle_pedido(id_pedido);

DROP INDEX IF EXISTS idx_detalle_pedido_id_producto;

CREATE INDEX idx_detalle_pedido_id_producto
    ON detalle_pedido(id_producto);

DROP INDEX IF EXISTS idx_producto_categoria;

CREATE INDEX idx_producto_categoria
    ON producto(id_categoria);


