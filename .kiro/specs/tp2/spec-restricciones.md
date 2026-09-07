Necesito que crees un script SQL llamado `restricciones.sql` que agregue restricciones  de integridad a mi esquema (ver AGENTS.md para convenciones), con nombre explícito en  cada constraint:

1) En `producto`: reemplazá el CHECK existente de `precio` por uno llamado  chk_producto_precio_positivo que exija precio > 0 (no >= 0).

2) En `pedido`: una restricción llamada chk_pedido_fecha_no_pasada que impida que la `fecha` sea posterior a CURRENT_DATE (no se aceptan fechas futuras; los pedidos históricos pasados sí). Evaluá si conviene CHECK o trigger y explicame por qué elegiste esa opción.

3) En `usuario`: una restriccion llamada chk_username_unico que garantice el mail (columna que identifica al usuario) no se repita entre usuarios.

4) En `pedido`: una restriccion llamada chk_pedido_estado que impida que estado pueda pasar unicamente de 'PENDIENTE' a 'CONFIRMADO' o a 'CANCELADO', y de 'CONFIRMADO' a 'TERMINADO'. No se deben permitir otros cambios: saltos (ej. PENDIENTE → TERMINADO), retrocesos ni cambios desde estados finales (TERMINADO/CANCELADO).


