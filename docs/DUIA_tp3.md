
## Declaracion de uso de IA: TRABAJO PRACTICO Nº3

## Declaración de uso de IA: TRABAJO PRÁCTICO Nº3

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó — ¿por qué? |
|---|---|---|---|
| **OpenCode** | Se utilizó para obtener una explicación en lenguaje natural, nodo por nodo, del plan generado por `EXPLAIN ANALYZE` en la consulta 1 del punto 2. | **Prompt:** "¿Me explicás en lenguaje natural el siguiente plan otorgado por `EXPLAIN ANALYZE`?" Se proporcionó el plan completo. | **Se aceptó** la explicación como punto de partida y posteriormente se realizaron comparaciones con el plan real para detectar posibles imprecisiones. |
| **OpenCode** | Se solicitaron 2 especificaciones precisas para 2 consultas sobre FoodStore: una consulta con resumen y otra con subconsulta. | **Spec:** `.kiro/specs/tp3/spec-solicitud.md` | **Se aceptaron** las consultas propuestas y posteriormente se verificaron con la base de datos. |
| **OpenCode** | Se solicitó ordenar la información recolectada en el archivo `spec-solicitud.md` con un formato adecuado para Markdown. | **Prompt:** "¿Me ordenás la información recolectada en este informe: código en un archivo `.md` llamado `spec-solicitud.md` para que pueda leerse de manera correcta?" | **Se aceptó** el formato generado, ya que permitió organizar la información de manera clara y legible. |






