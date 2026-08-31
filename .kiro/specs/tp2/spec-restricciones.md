Necesito que crees un script SQL llamado `restricciones.sql` que agregue restricciones  de integridad a mi esquema (ver AGENTS.md para convenciones), con nombre explícito en  cada constraint:

1) En `producto`: reemplazá el CHECK existente de `precio` por uno llamado  chk_producto_precio_positivo que exija precio > 0 (no >= 0).

2) En `pedido`: una restricción llamada chk_pedido_fecha_no_pasada que impida que  fecha_pedido sea anterior a CURRENT_DATE. Evaluá si conviene CHECK o trigger y  explicame por qué elegiste esa opción.

3) En `usuario`: una restriccion llamada chk_username_unico que garantice el username no serepita entre usuarios.

4) En `pedido`: una restriccion llamada chk_pedido_estado que impida que estado pueda pasar unicamente de 'PENDIENTE' a 'CONFIRMADO' o a 'CANCELADO', de 'CONFIRMADO' a 'TERMINADO' y no se puedan dar otros tipos de cambios como de 'PENDIENTE' a 'CONFIRMADO' o de 'CONFIRMADO' a TERMINADO' .


