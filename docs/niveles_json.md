# Niveles JSON jugables

La escena inicial `scenes/levels/playable_level.tscn` construye el nivel activo de la secuencia cada vez que comienza la partida.

## Flujo de trabajo

1. Servir el editor con `node tools/level-editor/serve.js` y abrir `http://localhost:8080/tools/level-editor/`.
2. Diseñar el nivel (o abrir uno existente con *Abrir…*) y guardarlo con `Ctrl+S`: se escribe directo en `level_designs/levels/` y el editor ofrece sumarlo a la secuencia; el orden se ajusta desde *Secuencia…*.
3. Ejecutar el proyecto. No es necesario convertir manualmente el JSON en una escena `.tscn`.

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
- El cielo declarado por `sky`, que además coloca el sol.

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

Una conexión también puede declarar `waypoints`, una lista ordenada de puntos `{x, z}` por los que el recorrido tiene que pasar. Con puntos, el trazado automático de la tabla se reemplaza: el pasillo une puerta, puntos y puerta con tramos en ángulo recto, siempre saliendo y llegando perpendicular a las paredes. Un punto alineado con el tramo no agrega codos, y un desvío que vuelve sobre su propia línea se descarta: un pasillo superpuesto consigo mismo no se puede construir sano. En la herramienta se agregan con doble click sobre el pasillo, se arrastran, y se quitan con click derecho.

El primer punto (o el último, del lado destino) además puede **mover la puerta**: si queda enfrentado a la pared, la puerta se desliza hasta su altura —con tope para no invadir la esquina— y el vano, la barrera que lo sella y el pasillo salen de ese lugar. `doorPoint` en la herramienta y `PlayableLevel._door_point` en el juego comparten ese cálculo, y `_collect_room_openings` propaga el corrimiento al tallado del vano.

El pasillo va cerrado, con piso, paredes y techo, a la altura del vano más bajo que une, así que su techo apoya contra el dintel. Cada codo recorta medio ancho los tramos que lo tocan —o sus paredes cruzarían el giro—, aporta el piso y el techo del giro y levanta pared sólo en las dos caras por las que el pasillo no entra ni sale. Dos tramos paralelos a menos del ancho del pasillo se invaden las paredes mutuamente: el smoke test de pasillos lo detecta como pasillo bloqueado.

El trazado está implementado dos veces, y a propósito: `corridorPlan` en `tools/level-editor/level-format.js` para dibujar el plano y `PlayableLevel._corridor_plan` para construir la geometría. `tests/corridor_layout_smoke_test.gd` recorre cada pasillo de la campaña con raycasts a la altura de los ojos —por el eje y pegado a cada lado— y comprueba que haya techo encima, así que una divergencia entre ambas se detecta como un pasillo bloqueado o descubierto. `tests/corridor_waypoints_smoke_test.gd` fija el contrato del trazado por puntos con los mismos casos que verifica el smoke test del editor del lado JS.

## Recorrido de la ronda

El cronómetro no corre mientras el jugador sigue en la sala `start`: arranca al salir de ella y se detiene al pisar la sala `exit`. Alcanzar la salida cierra el nivel y, tras `results_delay`, aparece la pantalla de resultados. Desde ahí el jugador reintenta, avanza al siguiente de la secuencia o vuelve al menú principal; si era el último, no se ofrece avanzar.

## Responsabilidades

- `LevelDefinitionLoader` valida la versión, las referencias y los valores del JSON, y resuelve los valores heredados (altura, techo, texturas, ancho de pasillo).
- `PlayableLevel` construye geometría, pasillos, iluminación, jugador y ronda.
- `ConfiguredRoomEncounter3D` interpreta las oleadas de cada sala y las despliega en orden: una empieza cuando se limpia la anterior.
- `WindowCatalog` traduce la familia declarada en cada capa a la escena que se instancia.

## La entrada es un valor derivado

`entry.wall` no se elige a mano. La herramienta lo recalcula recorriendo el nivel desde la sala de inicio: se entra a cada sala por la pared del pasillo que trajo al jugador, y a la sala de inicio por la pared que le queda a la espalda según su `facing`. Godot lee el campo ya resuelto en vez de repetir el cálculo, así que el editor es la única fuente de esa decisión y ambos lados no pueden divergir.

Cambiar el recorrido del nivel reorienta los bloques `left`, `front` y `right` en consecuencia, sin tocar su configuración.

## Oleadas, bloques y capas

El contenido de una sala se agrupa en dos niveles, y no se llaman igual a propósito:

```
sala
└── waves[]            oleadas: grupos de bloques que aparecen juntos
    └── blocks{}         left / front / right
        └── layers[]       capas: tandas de ventanas dentro del bloque
            └── windows{}    familia: cantidad
```

- Una **oleada de sala** aparece entera. La siguiente no llega hasta que se cierran todos sus bloques. Las puertas se sellan una sola vez, al entrar, y se abren al terminar la última oleada.
- Una **capa** es una tanda de ventanas dentro de un bloque. Al romper la última aparece la siguiente; al terminar la última capa el bloque se cierra.

Así se declara el ejemplo de una sala que ataca de frente y después por los costados: la primera oleada trae el bloque frontal con dos capas de cinco, la segunda un lateral con dos capas de cinco, y la tercera el otro lateral con una capa de diez.

Una oleada sin bloques habilitados se saltea, en vez de dejar la sala esperando un cierre que no va a llegar. Lo mismo pasa cuando una descarga infectada cuelga un bloque: esa pared queda ocupada por la pantalla de error, así que lo que las oleadas siguientes ponían ahí no aparece, y si una oleada se queda sin nada por eso, se saltea también. Una sala tolera hasta `MAX_ROOM_WAVES` (8) oleadas.

Cada bloque usa el siguiente contrato:

- `enabled`: si el bloque existe en esa oleada.
- `movement`: `static` u `opposite`.
- `movementSpeed`: velocidad en metros por segundo, entre 0.05 y 5.
- `color`: color hexadecimal aplicado al panel y a sus esferas normales.
- `layers`: lista ordenada de capas. Cada una declara `windows`, un mapa de familia a cantidad: `{"normal": 4, "firewall": 1}` son cinco ventanas, una de ellas firewall.

Una lista de capas vacía conserva el comportamiento de bloque sin objetivos, con el control rojo de cierre.

### Familias de ventana

Las familias y su comportamiento están en [`ventanas.md`](ventanas.md). En la herramienta se editan con chips: un clic suma una ventana de esa familia, clic derecho resta. Las que todavía no tienen escena propia se juegan como `normal`: el nivel las declara igual y empiezan a portarse distinto el día que su escena exista, sin tocar el archivo.

### Migración desde v8

Hasta v8 la sala tenía un único grupo de bloques y los tres aparecían juntos; dentro del bloque, lo que hoy son `layers` se llamaba `waves`. `LevelDefinitionLoader` migra ese formato al cargar: el grupo único pasa a ser la primera y única oleada. La migración es en memoria, así que un archivo viejo se juega sin convertirlo, y la herramienta lo guarda ya en v9 la primera vez que se lo edita.

El panel cubre su pared entera menos `WALL_MARGIN` (0,4 m) a lo ancho y a lo alto, de modo que no queda hueco por el que colarse mientras avanza hacia el lado contrario.

## Cielos

`SkyCatalog` (`scripts/environment/sky_catalog.gd`) define los cielos disponibles: `clear-day`, `overcast`, `sunset` y `night`. Cada uno arma un `ShaderMaterial` sobre `assets/skies/sky.gdshader` —un shader de cielo procedural, con nubes de ruido y estrellas— y **coloca la luz direccional**: el shader deduce la hora del día de `LIGHT0_DIRECTION`, así que mover el sol es lo que cambia el cielo de día a noche y lo que hace que la iluminación de la escena acompañe a lo que se ve arriba.

La lista está escrita dos veces, en `SkyCatalog.SKIES` y en `SKY_LABELS` de `tools/level-editor/level-format.js`. `tests/level_editor_smoke_test.mjs` lee el `.gd` y compara ambas contra el enum del schema, así que agregar un cielo en un solo lado falla la prueba.

Un `sky` desconocido cae en el cielo por defecto en vez de romper la carga.

## Texturas

`TextureCatalog` (`scripts/environment/texture_catalog.gd`) lee `level_designs/texture-catalog.json` —el mismo archivo que la herramienta usa para ofrecer la lista— y arma un `StandardMaterial3D` por identificador. La relación identificador → archivo vive en un solo lugar, así que la tool y el juego no pueden divergir.

Cada sala texturiza `walls`, `floor` y `ceiling`; el pasillo hereda las de la sala de la que sale. Un identificador vacío o desconocido cae en el material de color plano de siempre, así que un nivel sin texturas se construye igual que antes.

### Por qué proyección triplanar

Las cajas CSG traen UV de 0 a 1 **por cara**, no en metros: mapear por UV estira el mosaico según la proporción de cada superficie, y un piso de 22 × 18 y una pared de 22 × 6 muestran la textura a escalas distintas. Por eso los materiales usan `uv1_triplanar` con `uv1_world_triplanar`: la textura se proyecta desde el espacio de mundo, el mosaico mide lo mismo en todas las superficies y además calza entre cajas vecinas. El campo `tile` de cada entrada dice cuántos metros mide un mosaico.

### Assets

Se versiona la selección en uso, en 256 × 256, bajo `assets/textures/packs/<Material>/` (Bricks, Wood, Metal, ...). Los paquetes completos siguen comprimidos en `assets/_raw/textures/`, fuera de Git. Para sumar una textura: extraerla, copiarla a la carpeta de su material, agregar la entrada al catálogo y ya aparece en la herramienta y en el juego.

Ya no hay un nivel comparador versionado: `tests/texture_catalog_smoke_test.gd` arma uno en memoria con una sala por pack y verifica que cada una resuelva sus texturas.
