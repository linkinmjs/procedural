# Niveles JSON jugables

La escena inicial `scenes/levels/playable_level.tscn` construye el nivel activo de la secuencia cada vez que comienza la partida.

## Flujo de trabajo

1. Diseñar o importar un nivel en `tools/level-editor/index.html`.
2. Descargar el JSON dentro de `level_designs/levels/`.
3. Agregar su ID y ruta a `level_designs/level-sequence.json` en el orden deseado.
4. Ejecutar el proyecto. No es necesario convertir manualmente el JSON en una escena `.tscn`.

`LevelSequence` conserva el índice actual al recargar la escena y permite navegar manualmente con F7 y F8.

## Qué se construye

- Una sala física por cada entrada de `rooms`, con sus dimensiones en metros y la altura de paredes que declare, propia o heredada del nivel.
- Un techo sobre las salas cerradas. Las salas a cielo abierto quedan sin tapa y muestran el entorno.
- Pasillos transitables entre cada par de salas conectado, con el ancho de cada conexión. El vano que perforan en la pared usa ese mismo ancho, así que un pasillo estrecho deja una puerta estrecha.
- Puertas que sellan cada vano mientras la sala tiene bloques en pie.
- Iluminación independiente para salas y pasillos, colgada bajo el techo de cada sala.
- Un trigger por sala que despliega sus bloques al ingresar.
- Bloques izquierdo, frontal y derecho relativos a la pared de entrada, cubriendo su pared completa de piso a techo.
- El jugador dentro de la sala marcada como `start`, orientado según su `facing`, con la munición de `startingAmmo`.
- Un bloque de munición en el centro de las salas que declaran `ammoReward`, al caer su último bloque.
- El HUD y el tiempo de ronda de `timeLimitSeconds`.

## Geometría sólida

Todo el volumen del nivel — pisos, paredes, techos y pasillos — se construye dentro de un único `CSGCombiner3D` llamado `LevelShell`. La unión CSG funde las cajas que se tocan y descarta las caras internas, que es lo que antes se veía como costuras y parpadeos donde una sala y un pasillo se solapaban. La colisión sale del resultado ya combinado, así que la física ve exactamente la misma forma que se dibuja.

Las paredes se levantan enteras y los vanos se **restan** después, con cajas en modo `OPERATION_SUBTRACTION` que se agregan al final del árbol para que resten sobre el conjunto ya unido. Antes cada pared con puerta se armaba con dos medios tramos, y sus cantos quedaban a la vista a los lados del hueco.

El vano no llega al techo: mide `DOOR_HEIGHT` (3 m) y deja al menos `LINTEL_HEIGHT` (0,6 m) de pared arriba, de modo que después se pueda colgar una hoja de puerta. En una sala demasiado baja el vano se achica para conservar el dintel.

## Trazado de los pasillos

El recorrido es ortogonal y arranca **perpendicular a la pared que perfora**: una conexión norte / sur avanza primero en profundidad y una este / oeste, primero a lo ancho. Salir de costado dejaría la puerta mirando contra una pared.

Según cuánto estén desalineadas las dos puertas, `_corridor_plan` elige entre tres formas:

| Desfase | Forma |
| --- | --- |
| Nulo | Un tramo recto con el ancho declarado. |
| Menor o igual al ancho | Un tramo recto **ensanchado** hasta cubrir las dos puertas. No entra un codo: los dos giros se solaparían y se taparían entre sí. |
| Mayor que el ancho | Un codo de cuatro puntos. |

El pasillo va cerrado, con piso, paredes y techo, a la altura del vano más bajo que une, así que su techo apoya contra el dintel. Cada codo recorta medio ancho los tramos que lo tocan —o sus paredes cruzarían el giro—, aporta el piso y el techo del giro y levanta pared sólo en las dos caras por las que el pasillo no entra ni sale.

El trazado está implementado dos veces, y a propósito: `corridorPlan` en `tools/level-editor/level-format.js` para dibujar el plano y `PlayableLevel._corridor_plan` para construir la geometría. `tests/corridor_layout_smoke_test.gd` recorre cada pasillo de la campaña con raycasts a la altura de los ojos —por el eje y pegado a cada lado— y comprueba que haya techo encima, así que una divergencia entre ambas se detecta como un pasillo bloqueado o descubierto.

## Recorrido de la ronda

El cronómetro no corre mientras el jugador sigue en la sala `start`: arranca al salir de ella y se detiene al pisar la sala `exit`. Alcanzar la salida cierra el nivel y, tras `level_transition_delay`, arranca el siguiente de la secuencia. Si era el último, se registra `CAMPAIGN COMPLETE` y la escena se queda donde está.

## Responsabilidades

- `LevelDefinitionLoader` valida la versión, las referencias y los valores del JSON, y resuelve los valores heredados (altura, techo, texturas, ancho de pasillo).
- `PlayableLevel` construye geometría, pasillos, iluminación, jugador y ronda.
- `ConfiguredRoomEncounter3D` interpreta los bloques de cada sala y los activa una sola vez.

## La entrada es un valor derivado

`entry.wall` no se elige a mano. La herramienta lo recalcula recorriendo el nivel desde la sala de inicio: se entra a cada sala por la pared del pasillo que trajo al jugador, y a la sala de inicio por la pared que le queda a la espalda según su `facing`. Godot lee el campo ya resuelto en vez de repetir el cálculo, así que el editor es la única fuente de esa decisión y ambos lados no pueden divergir.

Cambiar el recorrido del nivel reorienta los bloques `left`, `front` y `right` en consecuencia, sin tocar su configuración.

## Configuración de bloques

Cada bloque usa el siguiente contrato:

- `movement`: `static` u `opposite`.
- `movementSpeed`: velocidad en metros por segundo, entre 0.05 y 5.
- `color`: color hexadecimal aplicado al panel y a sus esferas normales.
- `waves`: lista ordenada de cantidades. Por ejemplo, `[5, 10]` genera cinco objetivos y, al destruir el último, genera diez más.

El bloque se elimina solamente al completar su última oleada. Una lista vacía conserva el comportamiento de bloque sin objetivos, con el control rojo de cierre.

El panel cubre su pared entera menos `WALL_MARGIN` (0,4 m) a lo ancho y a lo alto, de modo que no queda hueco por el que colarse mientras avanza hacia el lado contrario.

## Pendiente: texturas

`defaults.textures` y `room.textures` se leen con `LevelDefinitionLoader.get_room_texture(level, room, slot)` y quedan reservadas hasta importar los packs de `assets/_raw/textures/`. Una cadena vacía significa "usar el material procedural actual". Al encararlo hay que elegir pack y resolución, extraer los archivos, importarlos, poblar `level_designs/texture-catalog.json` y cambiar los `StandardMaterial3D` procedurales de `PlayableLevel` por materiales con `albedo_texture` y `uv_scale` por superficie.
