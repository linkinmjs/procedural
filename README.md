# Procedural Map prototype

Prototipo para Godot 4.7 que integra SimpleDungeons y el FPS Template de Chaff Games.

## Estructura del proyecto

Layout separado (assets / scenes / scripts / resources), el recomendado para
proyectos medianos en Godot 4. Todo en `snake_case`, sin espacios ni mayusculas
en carpetas ni archivos.

```
assets/      # material crudo importable: modelos, texturas, audio, fuentes, iconos
  _raw/      # fuentes de trabajo (zips, proyectos de Reaper). Tiene .gdignore y no se versiona
resources/   # recursos .tres/.res de datos: armas, themes, animaciones, audio, entorno
scenes/      # escenas .tscn agrupadas por dominio
  player/ weapons/ projectiles/ levels/ targets/ windows/ ui/ environment/ sandbox/
scripts/     # scripts .gd espejando la estructura de scenes/
  autoloads/ player/ weapons/ projectiles/ levels/ targets/ windows/ ui/ gameplay/ environment/ sandbox/
level_designs/  # definiciones de nivel en JSON, leidas en runtime
addons/      # plugins de terceros (SimpleDungeons)
tests/       # smoke tests headless y visuales
tools/       # editor web de niveles (fuera del alcance de Godot via .gdignore)
docs/        # documentacion del proyecto
third_party/ # licencias y versiones de las fuentes de terceros
```

`scenes/sandbox/` agrupa los bancos de prueba jugables (dungeon, poligono de
armas, laboratorio de bloques): son escenas de desarrollo, no niveles de la
campania.

## Escenas

- `scenes/levels/playable_level.tscn`: nivel inicial jugable construido desde `level_designs/levels/nivel-1.json`.
- `scenes/sandbox/dungeon_test.tscn`: genera un dungeon recorrible y coloca al jugador en la sala de entrada.
- `scenes/sandbox/weapon_test.tscn`: poligono con cajas de municion y blancos reutilizables.
- `scenes/sandbox/block_lab.tscn`: laboratorio configurable de habitaciones y bloques de objetivos.
- `scenes/targets/target_spawn_volume_3d.tscn`: volumen configurable que distribuye pelotas estaticas y muestra sus limites de debug.
- `scenes/ui/round_hud.tscn`: HUD reutilizable de vida, tiempo, precision y eventos de ronda.

## Controles

- WASD: mover (se corre siempre); Espacio: saltar; Shift: caminar despacio; C: agacharse; Q/E: inclinarse.
- Mouse izquierdo: disparar; R: recargar; F: melee.
- F1: dungeon; F2: armas; F3: reiniciar escena; F4: laboratorio de bloques; F5: regenerar dungeon; F6: nivel JSON actual; F7/F8: nivel siguiente/anterior.

Al iniciar el proyecto se carga el nivel JSON configurado. Sus salas, techos, puertas, pasillos, luces, cielo, texturas, bloques de objetivos, municion y tiempo de ronda se construyen en runtime. Los encuentros aparecen al entrar en cada sala.

Al entrar a una sala que tiene bloques, sus vanos se sellan con una barrera roja
y no se abren hasta que caiga el ultimo bloque. Las salas sin bloques (Entrada,
Salida) nunca se sellan. La barrera cierra recien cuando el jugador se alejo del
vano y esta del lado de adentro, asi que ni lo atrapa dentro de la geometria ni
lo deja encerrado afuera si retrocede al pasillo.

El cronometro no corre mientras el jugador sigue en la habitacion de entrada: la ronda queda en `STANDBY` y arranca recien cuando la deja. Se detiene al pisar la ultima habitacion, la que cierra la cadena de conexiones (`Entrada -> ... -> Salida`), y la ronda termina con motivo `exit_reached`.

Los bloques JSON admiten color, velocidad individual y múltiples oleadas. Al destruir el último objetivo de una oleada aparece la siguiente; el bloque se cierra al completar todas. Los bloques spawnean ventanas estilo Windows, que se rompen disparando a la X, a un boton o a un cartel.

El orden jugable se define en `level_designs/level-sequence.json`. Al pisar la ultima habitacion la ronda se cierra y, tres segundos despues, arranca el siguiente nivel de la secuencia con el jugador en su entrada. La pausa se configura con `level_transition_delay` en la escena del nivel. En el ultimo nivel del catalogo no hay salto: el feed anuncia `CAMPAIGN COMPLETE`. F7 y F8 siguen sirviendo para cambiar de nivel a mano.

Las pelotas siguen disponibles como objetivo alternativo del bloque. Se destruyen con un impacto, y las variantes azules de penalizacion desaparecen a los 8 segundos y restan 15 HP si no son destruidas. Ni las pelotas ni las ventanas se mueven o reaparecen por su cuenta.

## Movilidad

Se corre por defecto y no hay estamina. La friccion y la aceleracion son las de
Quake, como en Counter-Strike 1.6: el arranque es casi inmediato, al soltar las
teclas queda un derrape corto y en el aire se conserva el impulso, con el control
justo para hacer strafe. Mantener el salto encadena rebotes y gana velocidad
hasta un tope. El detalle esta en [`docs/movilidad.md`](docs/movilidad.md).

## Arma

El jugador lleva una unica Glock semiautomatica con cargador de 10 balas y 60 de
reserva. Dispara con retroceso al estilo Counter-Strike 1.6: la vista sube con
cada tiro y vuelve sola al soltar el gatillo, y la punteria se abre al encadenar
disparos, al moverse y sobre todo en el aire. Agacharse la mejora. La mira
central muestra esa dispersion en tiempo real.

El detalle del sistema y los valores que conviene tocar estan en
[`docs/arma.md`](docs/arma.md).

## Laboratorio de bloques

Presiona F4 desde el dungeon o el poligono de armas. El menu inicial ofrece niveles predefinidos editables y tambien permite elegir manualmente habitacion pequena, grande o pasillo. Los bloques izquierdo, frontal y derecho se configuran de forma independiente. Cada uno admite entre 0 y 12 pelotitas y puede permanecer estatico o avanzar lentamente hacia el lado opuesto.

- Al romper todas sus pelotitas, el bloque se cierra.
- Con 0 pelotitas aparece un control rojo arriba a la derecha que permite cerrarlo de un disparo.
- Atravesar un bloque resta 15 HP por cruce.
- TAB abre o cierra la configuracion y pausa la prueba.

## Ventanas disparables

Las ventanas estilo Windows son los objetivos con personalidad que reemplazaran a las esferas dentro de un bloque. Cada una se dibuja como UI dentro de un `SubViewport`, se proyecta sobre un quad en 3D y se destruye disparando a la X, a un boton o a un cartel.

Hay dos estilos con su propio theme y template: Windows XP y retro gris. Para crear una ventana nueva se duplica el template correspondiente de `scenes/windows/templates/`. El procedimiento completo esta en [`docs/ventanas.md`](docs/ventanas.md).

`level_designs/levels/nivel-ventanas.json` es el nivel de pruebas del sistema. Esta al final del catalogo, asi que se llega con F7 desde el nivel inicial.

Prueba del sistema de ventanas:

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/window_panel_smoke_test.gd`

## Documentacion

- [`docs/guia_simple_dungeons.md`](docs/guia_simple_dungeons.md): funcionamiento del generador, habitaciones, puertas y alternativas para niveles procedurales, predefinidos o mixtos.
- [`docs/integration_notes.md`](docs/integration_notes.md): estado tecnico de la integracion y proximos pasos.
- [`docs/niveles_json.md`](docs/niveles_json.md): puente entre el editor web, los JSON versionados y la escena jugable de Godot.
- [`docs/ventanas.md`](docs/ventanas.md): como armar ventanas disparables desde los templates, marcar zonas y probarlas.
- [`docs/arma.md`](docs/arma.md): la Glock, su cargador, el retroceso y la imprecision dinamica.
- [`docs/movilidad.md`](docs/movilidad.md): velocidades, friccion, salto, airstrafe y bunny hop.
- [`docs/deuda_tecnica.md`](docs/deuda_tecnica.md): hallazgos de la revision de codigo pendientes de corregir.

## Editor de niveles

`tools/level-editor/` contiene un editor web local para componer salas desde arriba, unirlas con pasillos y configurar los bloques y objetivos de cada una. Por nivel define el tiempo, la munición inicial y los valores que heredan las salas; por sala, su rol (inicio, tránsito o salida), la altura de las paredes, si tiene techo o queda a cielo abierto, cuántas balas entrega al limpiarla y sus texturas. La pared por la que se entra a cada sala no se elige: sale del recorrido desde la sala de inicio. Por nivel también elige el cielo, que además coloca el sol. Los diseños exportados se guardan en `level_designs/` como JSON versionable (`schemaVersion: 6`). Las instrucciones de uso están en [`tools/level-editor/README.md`](tools/level-editor/README.md).

Prueba del editor y de los diseños versionados:

`node tests/level_editor_smoke_test.mjs`

Prueba automatizada del sistema:

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/target_system_smoke_test.gd`

Prueba del nivel JSON inicial:

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/playable_level_smoke_test.gd`

Prueba del arma:

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/glock_weapon_smoke_test.gd`

Prueba de la movilidad:

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/player_movement_smoke_test.gd`

## Direccion de desarrollo

Las habitaciones de `addons/SimpleDungeons/sample_dungeons` son material de prototipo. Para convertir el generador en una base del juego conviene crear un kit propio de `DungeonRoom3D` con conectores coherentes y usar `dungeon_done_generating` para poblar enemigos, objetivos, loot y encuentros despues de cerrar el layout.

## Despliegue automatico a itch.io

El workflow [`.github/workflows/deploy-to-itch.yml`](.github/workflows/deploy-to-itch.yml) exporta el preset `Web` y lo publica en itch.io en cada push a `main`. Los pull requests solo exportan (no publican).

### Configuracion inicial

1. Crear el proyecto en itch.io con **Kind of project: HTML**.
2. Cargar estos secretos en `Settings > Secrets and variables > Actions` del repositorio:
   - `BUTLER_API_KEY`: se obtiene en https://itch.io/user/settings/api-keys
   - `ITCHIO_GAME`: nombre del juego en itch (el de la URL)
   - `ITCHIO_USERNAME`: usuario de itch
3. Hacer push a `main`. La accion exporta el juego y lo sube.
4. Tras la primera subida, marcar en itch la opcion **This file will be played in the browser** y guardar.

### Notas tecnicas del export Web

- El proyecto corre en **Forward+** en escritorio, pero el export a Web solo soporta el renderer **Compatibility (WebGL2)**. Por eso `project.godot` define `renderer/rendering_method.web="gl_compatibility"`. Los efectos exclusivos de Forward+ (SDFGI, niebla volumetrica, SSAO/SSIL) no se ven en el build web.
- `export_presets.cfg` usa `include_filter="*.json"` porque los niveles de `level_designs/` se leen en runtime con `FileAccess` y no son recursos importados: sin ese filtro no viajarian dentro del `.pck`.
- El preset exporta sin soporte de hilos (`variant/thread_support=false`), que es la variante mas compatible con itch.io.
- La version de Godot del pipeline se controla con `GODOT_VERSION` / `GODOT_STATUS` en el workflow y debe coincidir con la del editor (hoy `4.7-stable`).
