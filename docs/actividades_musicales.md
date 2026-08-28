# Actividades musicales (rama experimental)

Una **actividad** es una ventana disparable que, en vez de una X o un botón,
trae un teclado de notas en cifrado americano y una consigna: *"Escala de C
mayor, ascendente"*, *"Notas del acorde de G menor"*, *"Quinta justa desde
B"*. Se resuelve disparando las teclas correctas —en orden si la actividad lo
pide— y recién ahí se cierra como cualquier otra ventana. Para bloques,
capas, oleadas y puertas es una ventana más, así que se puede mezclar con
las familias de siempre o reemplazarlas por completo.

La idea es usar el loop del juego para memorizar teoría: la ventana obliga a
leer la consigna, acordarse de la respuesta y ejecutarla con puntería, y cada
acierto suena la nota.

## Piezas

- [`scripts/music/music_theory.gd`](../scripts/music/music_theory.gd): la
  teoría. Notas como clases de altura (0 = C … 11 = B), y tablas de
  escalas, acordes e intervalos en semitonos. Nombra con sostenidos y muestra
  el enarmónico en las teclas negras (`C#/Db`).
- [`scripts/music/music_activity_catalog.gd`](../scripts/music/music_activity_catalog.gd):
  lee [`level_designs/music-activities.json`](../level_designs/music-activities.json)
  y convierte cada actividad en una **pregunta concreta** (`question_for`):
  elige la tónica, la calidad o el intervalo al azar entre lo que la
  actividad permite y deja la respuesta como lista de notas.
- [`scripts/windows/music_activity_window.gd`](../scripts/windows/music_activity_window.gd)
  y [`music_activity_window.tscn`](../scenes/windows/music_activity_window.tscn):
  la ventana. Arma el teclado por código (siete blancas y las negras
  montadas encima, cada una una zona disparable), compara contra la
  respuesta, tiñe, suena y puntúa.
- [`scripts/music/note_synth.gd`](../scripts/music/note_synth.gd): el sonido
  de las teclas. Un C4 sintetizado una vez en memoria; las demás notas salen
  de `pitch_scale`. Misma doctrina que `LedHumSynth`.

## Cómo se juega una actividad

| Situación | Qué pasa |
| --- | --- |
| Nota correcta | Suena la nota, la tecla queda verde, avanza la línea de progreso (`C D _ _ _ _ _ _`). Se informa la zona `note` (10 puntos, suma a la cadena). |
| Última nota correcta | Se informa `close` (100 puntos, cuenta como objetivo resuelto) y la ventana se cierra minimizándose. |
| Nota equivocada | Suena la nota más baja, la ventana destella en rojo y se informa `trap`: −150 y **la cadena se cierra**, igual que en el error crítico. Con `onMiss: "restart"` además se borra el progreso. |
| Barra de título | Trae la ventana al frente, como en todas. No hay X: una actividad no se descarta. |
| Firewall en la capa | La actividad queda protegida como cualquier hermana. |

Las teclas siempre se rearman: una escala repite la tónica arriba, y la nota
que estuvo mal puede ser la que toca después.

En las respuestas **ordenadas** (escalas, arpegios) sólo vale la nota que
sigue. En las **sin orden** (notas de un acorde) vale cualquiera que falte,
y repetir una ya encontrada cuenta como error.

## Definir actividades

Todo vive en `level_designs/music-activities.json`. Agregar una actividad es
una entrada más; ninguna requiere código. Campos (los que no se declaran
toman el valor de `MusicActivityCatalog.DEFAULTS`):

| Campo | Valores | Qué hace |
| --- | --- | --- |
| `id` | slug en minúsculas | Lo que referencian los niveles como `music:<id>`. |
| `name` | texto | Título de la ventana. |
| `question` | `note`, `scale`, `chord`, `interval` | Qué se pregunta. |
| `roots` | lista de notas (`["C", "Bb"]`), `"naturals"` o `"any"` | Tónicas posibles; se elige una al azar por ventana. `"any"` sólo abre las negras con paleta cromática. |
| `mode` | claves de `MusicTheory.SCALES`: `major`, `minor`, `harmonic-minor`, `major-pentatonic`, `minor-pentatonic`, `chromatic` | Escala, para `scale`. |
| `direction` | `up`, `down`, `both` | Sentido de la escala. Bajando arranca en la tónica y cae; ida y vuelta no repite la nota de arriba. |
| `octave` | bool | Si la escala cierra con la tónica del otro extremo. |
| `qualities` | claves de `MusicTheory.CHORDS`: `major`, `minor`, `diminished`, `augmented`, `dominant-7`, `major-7`, `minor-7` | Calidades posibles, para `chord`. |
| `intervals` | claves de `MusicTheory.INTERVALS`: `m2 M2 m3 M3 P4 TT P5 m6 M6 m7 M7 P8` | Intervalos posibles, para `interval`. |
| `ordered` | bool | Si hay que tocar en orden. Las escalas siempre lo son; un acorde ordenado es un arpegio. |
| `palette` | `natural` (7 teclas), `chromatic` (12) | Teclado. Si la respuesta usa una negra, pasa solo a cromático. |
| `hints` | bool | Modo guiado: ilumina la tecla que sigue (o las que faltan, si no hay orden). |
| `onMiss` | `continue`, `restart` | Si el error borra el progreso. |

Las actividades de fábrica están ordenadas por dificultad: encontrar una
nota, escala de C guiada, la misma bajando y sin ayuda, escalas con tónica al
azar (aparecen los sostenidos), tríadas mayores y menores en cualquier orden,
arpegios, tríadas mezcladas con reinicio, intervalos básicos y todos los
intervalos.

Los textos de la consigna salen de `resources/i18n/strings.csv`
(`MUSIC_PROMPT_*`, `MUSIC_MODE_*`, `MUSIC_CHORD_*`, `MUSIC_INTERVAL_*`):
agregar una escala o un acorde a las tablas de `MusicTheory` pide su fila de
traducción con la clave en mayúsculas (`harmonic-minor` →
`MUSIC_MODE_HARMONIC_MINOR`).

## En los niveles y en el laboratorio

En una capa se nombran como cualquier familia:

```json
{ "windows": { "music:escala-c-mayor-asc": 1, "normal": 2 } }
```

`WindowCatalog.spawn_plan_for()` resuelve `music:<id>` a la escena de
actividad con la actividad entera como configuración; la ventana la recibe
en `variant_config` antes de `add_child`, igual que los diseños del Window
Workshop. Un id que ya no existe degrada a una ventana `normal` con un aviso,
así que borrar una actividad nunca rompe un nivel.

El **Block Lab** (F4) suma todas las actividades del catálogo al desplegable
de familias, con el prefijo *Musica //*, y trae el preset *Musica // escala,
triada e intervalo* con una actividad por pared y dos capas cada una.

El Level Workshop acepta y etiqueta las claves `music:` (chip verde con ♪)
pero todavía no las ofrece en la paleta de familias: por ahora se escriben a
mano en el JSON o se prueban desde el laboratorio.

## Tamaño y puntería

La ventana mide 480 × 230 px a 90 píxeles por metro (5,3 × 2,6 m), más
grande que las demás porque siete teclas necesitan lugar. Cada tecla blanca
mide unos 0,7 × 1,4 m; las negras, 0,45 × 0,8 m. Dentro de un bloque conviene
poner **una actividad por capa**: dos se superpondrían y el teclado de atrás
quedaría tapado.

## Puntaje

Los valores viven en `resources/gameplay/score_settings.tres`: `note` (10)
por nota intermedia, `close` (100) por la que completa y `trap` (−150) por
el error. El techo de puntaje del nivel (`LevelScorePlan`) sigue contando una
actividad como **un** objetivo de 100, así que una sala con actividades puede
superar su techo con las notas intermedias. Es una aproximación aceptable
para la rama experimental; si las actividades pasan a la campaña, el plan
tiene que contar las notas de cada respuesta.

## Probar

Contrato completo (teoría, catálogo, preguntas, ventana, puntaje y bloque):

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/music_activity_smoke_test.gd`

Vista de tres actividades en `.godot/music-activity.png` (escala guiada con
dos notas tocadas, tríada y intervalo):

`Godot_v4.7-stable_win64_console.exe --path . res://tests/music_activity_visual_smoke_test.tscn`

La paridad tool ↔ juego del patrón `music:` la cubre
`node tests/level_editor_smoke_test.mjs`.
