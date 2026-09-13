-- ============================================
-- POBLACIÓN DE LA BASE DE DATOS FOODSTORE
-- 20,000 usuarios | 50,000 productos | 200,000 pedidos | ~600,000 detalles
-- Ejecutar después de schema.sql y restricciones.sql
--
-- IDEMPOTENTE: cada sección usa ON CONFLICT DO NOTHING (o consulta
-- generate_series que solo inserta lo faltante), por lo que es seguro
-- re-ejecutarlo sobre una base ya poblada: no duplica datos.
-- ============================================

-- ============================================
-- 1) CATEGORÍAS (20)
-- ============================================
INSERT INTO categoria (nombre) VALUES
    ('Frutas y Verduras'),
    ('Carnes y Aves'),
    ('Lácteos y Huevos'),
    ('Panadería'),
    ('Bebidas'),
    ('Snacks'),
    ('Enlatados'),
    ('Cereales y Granos'),
    ('Condimentos y Especias'),
    ('Congelados'),
    ('Pescados y Mariscos'),
    ('Frutos Secos'),
    ('Pastas y Salsas'),
    ('Postres'),
    ('Bebidas Alcohólicas'),
    ('Higiene Personal'),
    ('Limpieza'),
    ('Mascotas'),
    ('Bebés'),
    ('Otros')
ON CONFLICT DO NOTHING;

-- ============================================
-- 2) USUARIOS (20,000)
--    Nota: los ids reales dependen de la secuencia; al re-ejecutar solo
--    se insertan los mails que faltan (los ya existentes se ignoran).
-- ============================================
INSERT INTO usuario (nombre, apellido, mail, celular, contrasena)
SELECT
    (ARRAY[
        'Carlos','María','Juan','Ana','Pedro','Laura','Miguel','Sofía','Diego','Valentina',
        'Andrés','Camila','Roberto','Isabella','Fernando','Luciana','José','Gabriela','Luis','Daniela',
        'Manuel','Paula','Sergio','Mariana','Ricardo','Adriana','Eduardo','Carolina','Alejandro','Patricia',
        'Francisco','Claudia','Rafael','Rocío','Javier','Elena','Arturo','Diana','Gonzalo','Lorena',
        'Óscar','Teresa','Enrique','Mónica','Emilio','Carmen','Tomás','Silvia','Pablo','Esteban'
    ])[1 + floor(random() * 50)::int],
    (ARRAY[
        'García','López','Martínez','González','Hernández','Rodríguez','Pérez','Sánchez','Ramírez','Torres',
        'Flores','Rivera','Gómez','Díaz','Cruz','Morales','Reyes','Ortiz','Gutiérrez','Chávez',
        'Ruiz','Vargas','Castillo','Jiménez','Moreno','Romero','Herrera','Medina','Aguilar','Vega',
        'Castro','Mendoza','Silva','Rojas','Peña','Córdoba','Espinoza','Navarro','Campos','Cortés',
        'Domínguez','Soto','Rangel','Fuentes','Delgado','Salazar','Paredes','Acosta','León','Miranda'
    ])[1 + floor(random() * 50)::int],
    'user_' || gs || '@example.com',
    '+52' || (1000000000 + floor(random() * 9000000000)::bigint)::text,
    md5(random()::text || gs::text)
FROM generate_series(1, 20000) gs
ON CONFLICT (mail) DO NOTHING;

-- ============================================
-- 3) PRODUCTOS (50,000) — distribuidos en categorías existentes
-- ============================================
WITH cats AS (
    SELECT id_categoria,
           ROW_NUMBER() OVER (ORDER BY id_categoria) - 1 AS rn,
           COUNT(*) OVER () AS total
    FROM categoria
    WHERE deleted_at IS NULL
)
INSERT INTO producto (nombre, precio, descripcion, stock, id_categoria)
SELECT
    (ARRAY[
        'Manzana','Plátano','Naranja','Lechuga','Tomate','Papa','Zanahoria','Cebolla','Ajo','Pimiento',
        'Pollo','Carne de Res','Cerdo','Tilapia','Salmón','Huevo','Leche','Queso','Yogur','Mantequilla',
        'Pan Blanco','Pan Integral','Croissant','Torta','Galletas','Coca-Cola','Pepsi','Agua','Jugo','Café',
        'Papas Fritas','Chocolate','Gomitas','Nueces','Almendras','Atún','Sardina','Frijol','Arroz','Pasta',
        'Aceite','Sal','Pimienta','Orégano','Azúcar','Harina','Maíz','Avena','Sopa','Salsa',
        'Helado','Pudín','Flan','Tiramisú','Cheesecake','Cerveza','Vino','Tequila','Ron','Whisky',
        'Shampoo','Jabón','Pasta Dental','Desodorante','Papel Higiénico','Detergente','Suavizante','Cloro','Esponja','Bolsa',
        'Whiskas','Pedigree','Arena','Juguete','Pañales','Leche Fórmula','Wipes','Chupón','Papel','Cereal'
    ])[1 + floor(random() * 80)::int]
    || ' ' || (ARRAY[
        'Premium','Orgánico','Light','Extra','Familiar','Mini','XL','Natural','Integral','Gourmet'
    ])[1 + floor(random() * 10)::int]
    AS nombre,
    (random() * 490 + 10)::decimal(10,2) AS precio,
    'Producto de alta calidad para tu hogar' AS descripcion,
    (random() * 500)::int AS stock,
    c.id_categoria
FROM generate_series(0, 49999) gs
JOIN cats c ON c.rn = gs % c.total
ON CONFLICT DO NOTHING;

-- ============================================
-- 4) PEDIDOS (200,000)
--    Se toma id_usuario desde los IDs reales de la tabla usuario para
--    garantizar que siempre exista la FK.
-- ============================================
WITH usuarios_ids AS (
    SELECT id_usuario,
           ROW_NUMBER() OVER (ORDER BY id_usuario) - 1 AS rn,
           COUNT(*) OVER () AS total
    FROM usuario
    WHERE deleted_at IS NULL
)
INSERT INTO pedido (fecha, estado, forma_pago, id_usuario)
SELECT
    (NOW() - (random() * INTERVAL '365 days'))::timestamptz,
    (ARRAY['PENDIENTE','CONFIRMADO','TERMINADO','CANCELADO'])[1 + floor(random() * 4)::int]::estado_pedido,
    (ARRAY['EFECTIVO','CREDITO','DEBITO','TRANSFERENCIA','TARJETA'])[1 + floor(random() * 5)::int]::forma_pago,
    u.id_usuario
FROM generate_series(1, 200000) gs
JOIN usuarios_ids u ON u.rn = floor(random() * u.total)::int;

-- ============================================
-- 5) DETALLE PEDIDO (1-5 productos distintos por pedido)
-
-- ============================================
WITH pedidos_sin_detalle AS (
    SELECT p.id_pedido,
           ROW_NUMBER() OVER (ORDER BY p.id_pedido) - 1 AS rn,
           COUNT(*) OVER () AS total
    FROM pedido p
    WHERE p.deleted_at IS NULL
      AND NOT EXISTS (
          SELECT 1 FROM detalle_pedido d WHERE d.id_pedido = p.id_pedido
      )
),
pedidos_lote AS (
    SELECT * FROM pedidos_sin_detalle
    WHERE rn >= 0 AND rn < 10000
),
productos_ids AS (
    SELECT id_producto,
           ROW_NUMBER() OVER (ORDER BY id_producto) - 1 AS rn,
           COUNT(*) OVER () AS total
    FROM producto
    WHERE deleted_at IS NULL
),
order_info AS (
    SELECT
        p.id_pedido,
        (1 + floor(random() * 5))::int AS num_products,
        (floor(random() * pr.total))::int AS offset
    FROM pedidos_lote p
    CROSS JOIN (SELECT total FROM productos_ids LIMIT 1) pr
),
expanded AS (
    SELECT oi.id_pedido, oi.offset, gs.n AS line_num
    FROM order_info oi
    CROSS JOIN LATERAL generate_series(1, oi.num_products) AS gs(n)
)
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario, subtotal)
SELECT
    e.id_pedido,
    pr2.id_producto,
    (1 + floor(random() * 10))::int,
    0,
    0
FROM expanded e
JOIN productos_ids pr2 ON pr2.rn = ((e.offset + e.line_num - 1) % pr2.total);
