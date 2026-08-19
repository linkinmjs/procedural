# Diseños de niveles

Esta carpeta contiene las definiciones versionadas creadas con `tools/level-editor/`.

- `level-sequence.json` define el orden de los niveles jugables.
- Cada nivel vive en un archivo JSON independiente dentro de `levels/`.
- `old_levels/` guarda diseños que ya no forman parte de la campaña.
- `schema.json` documenta y valida el formato actual.
- `texture-catalog.json` lista las texturas disponibles: lo leen la herramienta y `TextureCatalog` en Godot, así que es la única fuente de la relación identificador → archivo.
- `three-room-example.json` sirve como referencia editable.
- Las posiciones y dimensiones están expresadas en metros, que son las mismas unidades que usa Godot.

## Formato actual

El formato usa `schemaVersion: 6`.

### Nivel

- `timeLimitSeconds`: tiempo límite global. El editor lo presenta en minutos y segundos.
- `startingAmmo`: `{ magazine, reserve }`, las balas con las que el jugador empieza el nivel. El cargador se recorta a la capacidad del arma.
- `sky`: cielo del nivel — `clear-day`, `overcast`, `sunset` o `night`. Además de pintar el cielo, coloca la luz direccional, así la iluminación de las salas acompaña a lo que se ve arriba. Si falta o nombra uno desconocido se usa `clear-day`.
- `defaults`: valores que heredan las salas y los pasillos.
  - `wallHeight`: altura de paredes en metros, entre 2 y 20.
  - `hasCeiling`: si las salas se cierran arriba.
  - `corridorWidth`: ancho por defecto de los pasillos.
  - `textures`: texturas por defecto para `walls`, `floor`, `ceiling`, `door` y `block`.

### Sala

- `role`: `start`, `transition` o `exit`. Un nivel declara exactamente una sala `start` y como mucho una `exit`.
- `facing`: dirección en grados hacia la que mira el jugador al aparecer. 0 es norte y los grados crecen hacia el este. Sólo se usa en la sala de inicio.
- `entry.wall`: **valor derivado**. La herramienta lo recalcula recorriendo el nivel desde la sala de inicio: se entra por la pared del pasillo que trajo al jugador, y en la sala de inicio por la pared que le queda a la espalda. No conviene editarlo a mano; el editor lo pisa en el próximo guardado.
- `wallHeight`: altura propia en metros, o `null` para heredar la del nivel.
- `hasCeiling`: `true` cerrada, `false` a cielo abierto, `null` para heredar.
- `ammoReward`: `{ enabled, amount, color }`. Con `enabled` en `true`, al destruir el último bloque de la sala aparece un bloque con `amount` balas.
- `textures`: identificadores del catálogo `texture-catalog.json`, por superficie. Una cadena vacía hereda la del nivel; si el nivel tampoco define una, se usa el material de color plano. El juego aplica hoy `walls`, `floor` y `ceiling`; `door` y `block` se guardan pero todavía no se dibujan.
- `blocks`: cada bloque define color, velocidad y una lista ordenada de oleadas. Los lados `left`, `front` y `right` son relativos a `entry.wall`: con una entrada `south`, el bloque `front` cae sobre la pared `north`. Cada bloque cubre su pared completa, de piso a techo.

### Conexión

- `fromWall` y `toWall` salen de la posición relativa de las dos salas.
- `width`: ancho del pasillo en metros. Su largo sale de la distancia entre las salas, así que separarlas en el plano alarga el pasillo. El vano que perfora la pared toma este mismo ancho.

El pasillo sale perpendicular a la pared que perfora: una conexión norte / sur avanza primero en profundidad y una este / oeste, primero a lo ancho. Con las puertas alineadas queda recto; desalineadas menos que su ancho, va recto y se ensancha para cubrir ambas; y con más desfase describe un codo. Va cerrado con piso, paredes y techo, y su altura es la del vano, no la de las salas.

## Migración

`tools/level-editor/migrate-level.js` actualiza archivos anteriores en el disco con la misma normalización que aplica el editor al importar. Los archivos sin `role` reciben uno según su nombre y su posición en la lista; los que no declaran `facing` orientan la sala de inicio hacia su primer pasillo, que es como los orientaba el runtime antes.
