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

- `scenes/ui/menus/main_menu.tscn`: escena inicial del proyecto. Escritorio con la ventana del menu principal.
- `scenes/levels/playable_level.tscn`: nivel jugable construido desde el JSON del nivel actual de la campania.
- `scenes/sandbox/dungeon_test.tscn`: genera un dungeon recorrible y coloca al jugador en la sala de entrada.
- `scenes/sandbox/weapon_test.tscn`: poligono con cajas de municion y blancos reutilizables.
- `scenes/sandbox/block_lab.tscn`: laboratorio configurable de habitaciones y bloques de objetivos.
- `scenes/targets/target_spawn_volume_3d.tscn`: volumen configurable que distribuye pelotas estaticas y muestra sus limites de debug.
- `scenes/ui/round_hud.tscn`: HUD reutilizable de vida, tiempo, precision y eventos de ronda. Incluye el controlador de puntaje y su HUD.
- `scenes/ui/score_hud.tscn`: contador de combo, marcador y resumen de nivel.

Los menus de pausa, confirmacion y resultados no son escenas: los arma
`MenuStack` sobre la escena en curso, para que el nivel siga vivo debajo.

## Controles

- WASD: mover (se corre siempre); Espacio: saltar; Shift: caminar despacio; C: agacharse; Q/E: inclinarse.
- Mouse izquierdo: disparar; R: recargar; F: melee.
- Esc: pausa; Retroceso: reintentar el nivel al instante, sin confirmacion.
- F1: dungeon; F2: armas; F3: reiniciar escena; F4: laboratorio de bloques; F5: regenerar dungeon; F6: nivel JSON actual; F7/F8: nivel siguiente/anterior.

Al iniciar el proyecto se abre el menu principal y jugar carga el nivel JSON del
punto de la campania donde se quedo. Sus salas, techos, puertas, pasillos, luces, cielo, texturas, bloques de objetivos, municion y tiempo de ronda se construyen en runtime. Los encuentros aparecen al entrar en cada sala.

Al entrar a una sala que tiene bloques, sus vanos se sellan con una barrera roja
y no se abren hasta que caiga el ultimo bloque. Las salas sin bloques (Entrada,
Salida) nunca se sellan. La barrera cierra recien cuando el jugador se alejo del
vano y esta del lado de adentro, asi que ni lo atrapa dentro de la geometria ni
lo deja encerrado afuera si retrocede al pasillo.

El cronometro arranca en cuanto hay algo que cronometrar: si la habitacion de entrada tiene bloques, al activarse su encuentro; si esta vacia, la ronda queda en `STANDBY` y arranca recien cuando el jugador la deja. Una sala en la que se pelea siempre corre con la ronda activa, porque en `STANDBY` los disparos, los fallos y el daño no se contabilizan. Se detiene al resolver la ultima habitacion, la que cierra la cadena de conexiones (`Entrada -> ... -> Salida`): al pisarla si no tiene objetivos, o al destruir el ultimo si los tiene. La ronda termina con motivo `exit_reached`.

El contenido de una sala se agrupa en dos niveles. Las **oleadas de sala** son grupos de bloques que aparecen juntos: la siguiente no llega hasta que se limpia la anterior, asi que una sala puede atacar de frente y despues por los costados. Las **capas** son tandas de ventanas dentro de un bloque: al romper la ultima aparece la siguiente y el bloque se cierra al terminarlas todas.

Cada capa declara que familia de ventana trae, y cada familia cobra algo distinto: la publicidad se llama a si misma mientras el contador de SKIP no deja cerrarla, el firewall protege a las demas hasta desactivarlo, el error critico baraja sus botones cada vez que se falla, la descarga paga mas si se la cancela rapido que si se la deja terminar, y la descarga infectada cuelga el bloque entero si llega al final. Disparar a la barra de titulo de cualquier ventana la trae al frente. El detalle esta en [`docs/ventanas.md`](docs/ventanas.md).

El orden jugable se define en `level_designs/level-sequence.json`. Al pisar la ultima habitacion la ronda se cierra y, tres segundos despues, aparece la pantalla de resultados con el desglose del puntaje: desde ahi se reintenta, se avanza al nivel siguiente o se vuelve al menu principal. La espera se configura con `results_delay` en la escena del nivel. Quedarse sin tiempo tambien abre los resultados, marcados como intento fallido y sin la opcion de avanzar. F7 y F8 siguen sirviendo para cambiar de nivel a mano.

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

Cada bloque declara ademas cuantas capas tiene, que familia de ventana reparte y en que oleada aparece. Con eso el laboratorio prueba lo mismo que permite el formato de nivel: poner el bloque frontal en la oleada 1 y los laterales en la 2 y la 3 reproduce el ataque escalonado sin escribir un JSON.

Los presets cubren una mecanica cada uno: tres oleadas, capas que se pelan de a poco, publicidad que se llama sola, descarga rapida contra lenta, descarga infectada en un bloque movil, firewall y una pared de ventanas apiladas para probar el traer al frente. `Mezcla` reparte una familia de cada una en la misma capa, salvo la infectada, que colgaria el bloque antes de que se vea el resto.

## Puntuacion

El puntaje no se cobra al impactar: cada objetivo resuelto suma a un **pozo**
pendiente que se multiplica entero cuando la cadena se cierra. Una cadena empieza
al entrar a una sala con objetivos y se cierra al limpiarla, asi que el techo de
cada sala se calcula desde su JSON y el rango es el porcentaje de ese techo que
se alcanzo.

- Acertar suma al pozo y sube la cadena; la cadena da el multiplicador por escalones (x1 a x8).
- Fallar hunde el multiplicador 2 escalones, 3 y 4 si se encadenan fallos, pero nunca toca el pozo.
- Recibir daño o acertar una zona trampa cierra la cadena y la cobra a x1.
- Limpiar la sala la cobra al multiplicador vigente y paga los bonos de sala.
- Terminar el nivel paga municion sobrante, tiempo restante y las corridas limpias, y entrega rango.

`RoundController` sigue siendo el unico punto al que reportan ventanas, pelotas y
bloques. `ScoreController` solo lo escucha: la ronda administra vida y tiempo, el
puntaje es otra responsabilidad. Todos los pesos viven en
[`resources/gameplay/score_settings.tres`](resources/gameplay/score_settings.tres).

El diseño completo esta en
[`docs/gdd_atractivo_y_progresion_ANEXO_puntuación.md`](docs/gdd_atractivo_y_progresion_ANEXO_puntuación.md).

Pruebas del sistema de puntuacion:

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/score_system_smoke_test.gd`

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/score_level_smoke_test.gd`

Vista del HUD de puntaje, en `.godot/score-hud-chain.png` (cadena viva) y `.godot/score-hud-bank.png` (cadena ya cobrada):

`Godot_v4.7-stable_win64_console.exe --path . res://tests/score_hud_visual_smoke_test.tscn`

## Menus

El juego arranca en un escritorio de Windows: fondo, iconos, barra de tareas con
boton de inicio y una ventana abierta. `MenuStack` es un autoload que apila los
menus sobre la escena en curso y es el unico que decide si el arbol esta pausado
y como esta el mouse.

Los menus se dibujan con una de dos pieles, y cada una dice donde esta parado el
jugador:

- **Windows** ([`xp_theme.tres`](resources/themes/xp_theme.tres)): solo el menu
  principal, porque ahi el sistema operativo no es decoracion sino el menu.
- **Juego** ([`game_theme.tres`](resources/themes/game_theme.tres)): la pausa, la
  confirmacion y los resultados, con los mismos paneles oscuros de acento cian
  que el HUD del nivel.

La separacion no es estetica: las ventanas de Windows son objetivos a los que se
les dispara, asi que un menu que se viera igual seria ambiguo. La piel se elige
con `skin` antes de llamar a `build_window()`.

- Escritorio: iconos de `procedural.exe`, niveles, opciones, mi pc y papelera. Un clic selecciona, y solo uno queda seleccionado a la vez; el doble clic ejecuta. `procedural.exe` abre la ventana del juego; los demas hacen parpadear el boton de la ventana en la barra, como un aviso pendiente, para devolver al jugador al juego.
- Barra de tareas: boton de inicio con su menu, boton de la ventana abierta y reloj. Cerrar la ventana la deja en la barra; su boton la vuelve a abrir. Si la ventana esta cerrada, el aviso queda encendido hasta que la abran.
- Menu principal: jugar el nivel actual de la campania, opciones y salir. Seleccionar nivel todavia no existe.
- Opciones: volumen general, musica y efectos; sensibilidad del mouse; idioma; ventana o pantalla completa y resolucion. Se abre desde el escritorio y desde la pausa.
- Entrada al nivel: un velo con el numero del nivel que entra y se va en poco mas de dos segundos. Cualquier tecla lo saltea y reintentar no lo muestra.
- Pausa: reanudar, reintentar y abandonar el nivel, que pide confirmacion.
- Resultados: unica pantalla de cierre del nivel. Desglose animado del puntaje, rango y record, con reintentar, avanzar y volver al menu. El HUD no repite el desglose: durante la espera deja a la vista el cobro de la ultima cadena.

Reintentar nunca pide confirmacion ni pasa por un menu: tiene la tecla Retroceso
durante la partida.

El diseño, las alternativas que se descartaron y lo que falta estan en
[`docs/gdd_atractivo_y_progresion_ANEXO_menus.md`](docs/gdd_atractivo_y_progresion_ANEXO_menus.md).

Pruebas de las oleadas de sala y de las familias de ventana:

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/room_waves_smoke_test.gd`

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/window_families_smoke_test.gd`

Vista de las familias, en `.godot/window-families.png` y `.godot/window-download-confirm.png`:

`Godot_v4.7-stable_win64_console.exe --path . res://tests/window_families_visual_smoke_test.tscn`

Prueba del flujo de menus:

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/menu_flow_smoke_test.gd`

Prueba de las opciones:

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/options_smoke_test.gd`

Vista de las opciones en las dos pieles, en `.godot/options-desktop.png` y `.godot/options-game.png`:

`Godot_v4.7-stable_win64_console.exe --path . res://tests/options_visual_smoke_test.tscn`

Vista de los menus, en `.godot/menu-main.png`, `.godot/menu-notify.png`, `.godot/menu-start.png`, `.godot/menu-pause.png` y `.godot/menu-results.png`:

`Godot_v4.7-stable_win64_console.exe --path . res://tests/menu_visual_smoke_test.tscn`

La entrada al nivel se ve en `.godot/level-intro.png`, que sale de la prueba
visual del nivel jugable.

## Opciones

Los ajustes del jugador viven en `user://settings.cfg` y los administra el
autoload [`Settings`](scripts/autoloads/settings.gd), unico lugar que toca
`AudioServer`, `TranslationServer` y `DisplayServer`.

- **Audio**: tres buses, `Master`, `Music` y `SFX`, definidos en [`resources/audio/default_bus_layout.tres`](resources/audio/default_bus_layout.tres). Hoy solo suena la Glock, que va por `SFX`. Volumen cero silencia el bus en vez de bajarlo a casi nada.
- **Sensibilidad**: la lee el jugador del autoload, asi que cambiarla desde la pausa se siente sin recargar el nivel. Se guarda cruda y se muestra de 0 a 100.
- **Idioma**: cambia en caliente. Los controles guardan claves, asi que Godot los retraduce solos.
- **Pantalla**: ventana o pantalla completa, y resolucion.

No hay boton de aceptar: cada cambio se aplica y se guarda en el momento.

En la exportacion web el tamaño del lienzo lo decide la pagina que embebe el
juego, asi que la fila de resolucion queda a la vista pero apagada, explicando
por que. Pantalla completa si funciona, porque el navegador la concede cuando
sale de un clic.

## Idiomas

El juego esta en espaniol, portugues e ingles. Todos los textos salen de
[`resources/i18n/strings.csv`](resources/i18n/strings.csv), una fila por clave y
una columna por idioma; Godot lo importa a un `.translation` por columna.

Los controles guardan la **clave** en su texto (`MENU_PLAY`, `HUD_TIME`) y Godot
la traduce al dibujar, asi que cambiar de idioma no necesita reconstruir la UI.
Lo que lleva datos adentro se arma con `tr("CLAVE").format({...})` y nunca con
`%s`: los idiomas no ordenan las palabras igual, y con nombres cada traduccion
mueve los huecos a donde le queda bien.

Los rangos (`GUEST`, `ADMIN`, `ROOT`, `KERNEL`) no se traducen a proposito: son
los niveles de usuario del sistema operativo que el juego imita, no palabras
sueltas. Tampoco se traducen los nombres de los niveles y las salas, que son
contenido y viven en los JSON de `level_designs/`.

El idioma sale del sistema, con espaniol como respaldo. Para probar otro:

`Godot_v4.7-stable_win64_console.exe --path . --language pt res://tests/menu_visual_smoke_test.tscn`

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
- [`docs/gdd_atractivo_y_progresion_ANEXO_puntuación.md`](docs/gdd_atractivo_y_progresion_ANEXO_puntuación.md): pozo, cadena, bonos, techo y rangos del sistema de puntuacion.
- [`docs/gdd_atractivo_y_progresion_ANEXO_menus.md`](docs/gdd_atractivo_y_progresion_ANEXO_menus.md): mapa de pantallas de menu, direcciones esteticas y arquitectura de navegacion.
- [`docs/gdd_atractivo_y_progresion_ANEXO_sonido.md`](docs/gdd_atractivo_y_progresion_ANEXO_sonido.md): inventario priorizado de efectos, ambientes y musica, con estado de integracion y criterios de reproduccion.
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
