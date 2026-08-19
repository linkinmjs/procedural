# Procedural Map prototype

Prototipo para Godot 4.7 que integra SimpleDungeons y el FPS Template de Chaff Games.

## Escenas

- `scenes/levels/playable_level.tscn`: nivel inicial jugable construido desde `level-designs/levels/nivel-1.json`.
- `scenes/dungeon_test.tscn`: genera un dungeon recorrible y coloca al jugador en la sala de entrada.
- `scenes/weapon_test.tscn`: poligono con cajas de municion y blancos reutilizables.
- `scenes/block_lab.tscn`: laboratorio configurable de habitaciones y bloques de objetivos.
- `scenes/targets/target_spawn_volume_3d.tscn`: volumen configurable que distribuye pelotas estaticas y muestra sus limites de debug.
- `scenes/ui/round_hud.tscn`: HUD reutilizable de vida, tiempo, precision y eventos de ronda.

## Controles

- WASD: mover; Espacio: saltar; Shift: correr; C: agacharse; Q/E: inclinarse.
- Mouse izquierdo: disparar; R: recargar; F: melee.
- F1: dungeon; F2: armas; F3: reiniciar escena; F4: laboratorio de bloques; F5: regenerar dungeon; F6: nivel JSON actual; F7/F8: nivel siguiente/anterior.

Al iniciar el proyecto se carga el nivel JSON configurado. Sus salas, puertas, conexiones, luces, bloques de objetivos y tiempo de ronda se construyen en runtime. Los encuentros aparecen al entrar en cada sala.

Los bloques JSON admiten color, velocidad individual y múltiples oleadas. Al destruir el último objetivo de una oleada aparece la siguiente; el bloque se cierra al completar todas. Los bloques spawnean ventanas estilo Windows, que se rompen disparando a la X, a un boton o a un cartel.

El orden jugable se define en `level-designs/level-sequence.json`. Por ahora F7 y F8 cambian de nivel manualmente. El avance automático queda deliberadamente desacoplado hasta implementar la condición de victoria.

Las pelotas siguen disponibles como objetivo alternativo del bloque. Se destruyen con un impacto, y las variantes azules de penalizacion desaparecen a los 8 segundos y restan 15 HP si no son destruidas. Ni las pelotas ni las ventanas se mueven o reaparecen por su cuenta.

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

`level-designs/levels/nivel-ventanas.json` es el nivel de pruebas del sistema. Esta al final del catalogo, asi que se llega con F7 desde el nivel inicial.

Prueba del sistema de ventanas:

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/window_panel_smoke_test.gd`

## Documentacion

- [`docs/guia_simple_dungeons.md`](docs/guia_simple_dungeons.md): funcionamiento del generador, habitaciones, puertas y alternativas para niveles procedurales, predefinidos o mixtos.
- [`docs/integration_notes.md`](docs/integration_notes.md): estado tecnico de la integracion y proximos pasos.
- [`docs/niveles_json.md`](docs/niveles_json.md): puente entre el editor web, los JSON versionados y la escena jugable de Godot.
- [`docs/ventanas.md`](docs/ventanas.md): como armar ventanas disparables desde los templates, marcar zonas y probarlas.
- [`docs/arma.md`](docs/arma.md): la Glock, su cargador, el retroceso y la imprecision dinamica.

## Editor de niveles

`tools/level-editor/` contiene un editor web local para componer salas desde arriba, conectarlas y configurar los bloques y objetivos de cada una. Los diseños exportados se guardan en `level-designs/` como JSON versionable. Las instrucciones de uso están en [`tools/level-editor/README.md`](tools/level-editor/README.md).

Prueba automatizada del sistema:

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/target_system_smoke_test.gd`

Prueba del nivel JSON inicial:

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/playable_level_smoke_test.gd`

Prueba del arma:

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/glock_weapon_smoke_test.gd`

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
- `export_presets.cfg` usa `include_filter="*.json"` porque los niveles de `level-designs/` se leen en runtime con `FileAccess` y no son recursos importados: sin ese filtro no viajarian dentro del `.pck`.
- El preset exporta sin soporte de hilos (`variant/thread_support=false`), que es la variante mas compatible con itch.io.
- La version de Godot del pipeline se controla con `GODOT_VERSION` / `GODOT_STATUS` en el workflow y debe coincidir con la del editor (hoy `4.7-stable`).
