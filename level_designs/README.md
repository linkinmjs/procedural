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

El formato usa `schemaVersion: 10`.

### Nivel

- `timeLimitSeconds`: tiempo límite global. El editor lo presenta en minutos y segundos.
- `startingAmmo`: `{ magazine, reserve }`, las balas con las que el jugador empieza el nivel. El cargador se recorta a la capacidad del arma.
- `sky`: cielo del nivel — `clear-day`, `overcast`, `sunset` o `night`. Además de pintar el cielo, coloca la luz direccional, así la iluminación de las salas acompaña a lo que se ve arriba. Si falta o nombra uno desconocido se usa `clear-day`.
- `defaults`: valores que heredan las salas y los pasillos.
  - `wallHeight`: altura de paredes en metros, entre 2 y 20.
  - `maxBlockHeight`: alto máximo del bloque de ventanas, entre 2 y 12. El bloque cubre el ancho entero de la pared y se levanta desde el piso hasta el techo o hasta este valor, lo que sea menor, para que los objetivos no queden fuera del ángulo cómodo de puntería. Por defecto, 6.
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
- `radio`: `{ enabled, corner }`. Con `enabled` en `true`, una radio con música en loop aparece en la esquina `corner` (`ne`, `nw`, `se`, `sw`; norte es -Z, este es +X), apoyada contra las dos paredes y mirando al centro. Se rompe de un disparo.
- `textures`: identificadores del catálogo `texture-catalog.json`, por superficie. Una cadena vacía hereda la del nivel; si el nivel tampoco define una, se usa el material de color plano. El juego aplica hoy `walls`, `floor` y `ceiling`; `door` y `block` se guardan pero todavía no se dibujan.
- `blocks`: cada bloque define color, velocidad y una lista ordenada de oleadas. Los lados `left`, `front` y `right` son relativos a `entry.wall`: con una entrada `south`, el bloque `front` cae sobre la pared `north`. Cada bloque cubre el ancho completo de su pared y se levanta desde el piso hasta `defaults.maxBlockHeight`, o hasta el techo si la sala es más baja.

### Oleada

Cada elemento de `blocks.<slot>.waves` declara cuántas ventanas de cada familia aparecen a la vez:

```json
{ "windows": { "normal": 4, "firewall": 2 } }
```

Las familias válidas son `normal`, `popup`, `download`, `firewall`, `critical-error`, `confirm`, `ad`, `fake-close`, `task-manager`, `corrupt-file` e `installer`, y salen de los comportamientos que enumera `docs/gdd_atractivo_y_progresion.md`. La lista vive en `WINDOW_TYPES` (`tools/level-editor/level-format.js`) y en `VALID_WINDOW_TYPES` (`scripts/levels/level_definition_loader.gd`), que tienen que coincidir. Una clave también puede ser `custom:<slug>`: un diseño de `window-designs.json` (ver abajo), o `music:<id>`: una actividad musical de `music-activities.json` (ver `docs/actividades_musicales.md`).

Sólo se guardan las familias con al menos una ventana, y el total de una oleada va de 1 a 64. Las familias sin comportamiento propio se spawnean como una ventana normal; el editor las marca como *pronto* para que se vea qué está declarado y qué está construido.

El formato anterior escribía la oleada como un número suelto (`"waves": [5]`); al importar o migrar se convierte en `{ "windows": { "normal": 5 } }`.

### Conexión

- `fromWall` y `toWall` salen de la posición relativa de las dos salas.
- `width`: ancho del pasillo en metros. Su largo sale de la distancia entre las salas, así que separarlas en el plano alarga el pasillo. El vano que perfora la pared toma este mismo ancho.
- `waypoints`: puntos `{x, z}` por los que el recorrido pasa, en orden. Vacío, el trazado se resuelve solo entre las dos puertas. El primero (o el último, del lado destino) también desliza la puerta sobre la pared cuando queda enfrentado a ella.

El pasillo sale perpendicular a la pared que perfora: una conexión norte / sur avanza primero en profundidad y una este / oeste, primero a lo ancho. Con las puertas alineadas queda recto; desalineadas menos que su ancho, va recto y se ensancha para cubrir ambas; y con más desfase describe un codo. Con `waypoints`, el pasillo une puerta, puntos y puerta con tramos en ángulo recto. Va cerrado con piso, paredes y techo, y su altura es la del vano, no la de las salas.

## Diseños de ventana (`window-designs.json`)

Los diseños custom que edita la pestaña **Ventanas** del Workshop, con `schemaVersion` propio (1), independiente del formato de niveles. Cada diseño: `{ id, slug, name, family, variants }`; cada variante: `{ base, skin, title, message, subtitle, size }`.

- `slug` (`[a-z0-9-]`, único) es lo que los niveles referencian como `custom:<slug>`. Se congela al crear el diseño: renombrarlo no rompe los archivos que lo usan.
- `family` es una de las familias con comportamiento propio; la variante sólo cambia lo estético. `base` elige cuál escena de la familia viste (`close`/`shutdown` para `normal`, `popup`/`popup-slow` para `popup`; el resto tiene una sola).
- `skin` re-viste el chrome: `"xp"` (Windows XP) o `"retro"` (Retro 97, gris con barra azul plana). Vacía usa la skin con la que la escena base está construida. La aplica `scripts/windows/window_skin.gd` sin tocar el comportamiento de la familia.
- Los textos vacíos dejan el de la escena; `size` en `null` usa el tamaño nativo de la base, y si se declara se acota a 200–560 × 110–320 px.

Lo leen `scripts/windows/window_design_catalog.gd` (el juego) y `tools/level-editor/window-format.js` (la tool), y un diseño borrado degrada a ventana `normal` sin invalidar los niveles que lo nombraban.

## Migración

`tools/level-editor/migrate-level.js` actualiza archivos anteriores en el disco con la misma normalización que aplica el editor al importar. Los archivos sin `role` reciben uno según su nombre y su posición en la lista; los que no declaran `facing` orientan la sala de inicio hacia su primer pasillo, que es como los orientaba el runtime antes.
