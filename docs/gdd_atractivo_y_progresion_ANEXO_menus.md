# Anexo — Menús y navegación

Anexo transversal de [`gdd_atractivo_y_progresion.md`](gdd_atractivo_y_progresion.md).
Toca sobre todo el eje 4 (lobby con escritorio), pero también el eje 1: la
pantalla de resultados y el reintento son parte del sistema de puntuación.

> **Este documento NO es la versión final.** Es un mapa de posibilidades para
> decidir sobre la marcha. Las opciones están puestas para compararlas, y las
> que ya se eligieron se eligieron para probarlas: son direcciones de arranque,
> no compromisos. Se espera que cambien al jugarlas.

**Estado:** En definición.

Estados que usamos, iguales a los del documento madre: **Propuesto**, **En
definición**, **Para prototipar**, **Confirmado**.

---

## 1. Alcance

Este anexo define **qué pantallas de menú necesita el juego, cómo se navega
entre ellas, quién las controla en el código y cómo se ven**. No define el
contenido del escritorio del lobby (iconos, fondos, desbloqueables): eso vive en
el eje 4 del documento madre. Sí define el hueco donde ese escritorio va a
entrar, para no rehacer la navegación cuando llegue.

---

## 2. De dónde partimos

Estado del proyecto **antes** de las fases 0 a 3, que es el problema que este
anexo vino a resolver. Lo que quedó armado está en la §9.

| Pieza | Estado actual |
| --- | --- |
| Escena principal | `scenes/levels/playable_level.tscn`: el juego arranca dentro de un nivel |
| Menú | No existe ninguno |
| `Esc` | Sólo libera y recaptura el mouse, desde `player_character.gd` |
| Pausa | No existe en el nivel; el laboratorio de bloques sí pausa el árbol |
| Navegación de niveles | Autoload `LevelSequence`, catálogo lineal de 3 niveles |
| Fin de nivel | Temporizador de 3 s y salto automático al siguiente |
| Resultados | Resumen dentro del `ScoreHUD`, sin pantalla propia ni reintento |
| Récords | `ScoreRecords` guarda por nivel en `user://score_records.cfg` |
| Debug | `F1`–`F4` cambian de escena a mano |
| Estilo de UI | Dos themes de ventana: `xp_theme.tres` y `retro_theme.tres` |

Tres conclusiones que condicionan todo lo que sigue:

1. **No hay un punto de entrada.** El juego empieza jugando. Cualquier menú
   implica mover `main_scene` y decidir quién arranca la partida.
2. **El control del mouse vive en el jugador.** Cualquier menú que se abra
   encima va a pelear con esa lógica si no la centralizamos antes.
3. **La navegación entre niveles ya está resuelta y es lineal.** Un selector de
   niveles no arranca de cero: arranca de `LevelSequence` más `ScoreRecords`.

---

## 3. El mapa de pantallas

Inventario de lo que el juego necesita, con prioridad propuesta.

| Pantalla | Para qué | Prioridad |
| --- | --- | --- |
| **Menú principal** | Punto de entrada: jugar, seleccionar, opciones, salir | Alta |
| **Pausa** | Reanudar, reintentar, opciones, abandonar el nivel | Alta |
| **Resultados de nivel** | Desglose de puntaje, rango, récord, reintento | Alta |
| **Selección de nivel** | Elegir nivel, ver rango y récord de cada uno | Media |
| **Opciones** | Video, audio, sensibilidad, controles | Media |
| **Confirmaciones** | Abandonar partida, borrar récords | Media |
| **Récords y estadísticas** | Historial por nivel y por sala | Baja |
| **Créditos** | Cierre | Baja |
| **Boot / carga** | Logo y precarga | Baja |

### Notas por pantalla

**Menú principal.** Mínimo viable: Jugar (arranca el nivel actual de la
secuencia), Seleccionar nivel, Opciones, Salir. En el futuro, esta pantalla es
la que el lobby reemplaza o absorbe.

**Pausa.** Regla heredada del anexo de puntuación (§11.2): *reiniciar el nivel
tiene que costar menos de un segundo y ninguna confirmación*. Por lo tanto el
reintento no es solamente un botón del menú de pausa: es además una tecla
dedicada disponible durante la partida. La pausa existe para el resto —
opciones, abandonar—, no para reintentar.

**Resultados.** El anexo de puntuación ya define el contenido y el
comportamiento: desglose animado línea por línea, salteable con una tecla,
reintento a un botón de distancia. Hoy el nivel salta solo a los 3 segundos: esa
transición automática es lo que esta pantalla reemplaza.

**Selección de nivel.** Todos los datos ya existen: `LevelSequence` da el
catálogo y `ScoreRecords` da puntaje máximo, precisión, tiempo e intentos. Es la
pantalla que después se convierte en iconos del escritorio.

**Opciones.** Lo mínimo que el juego ya necesita: sensibilidad del mouse,
volumen, pantalla completa y resolución. El rebind de controles es deseable pero
puede esperar; el `InputMap` ya está declarado en `project.godot`.

---

## 4. Dirección estética: tres caminos

Ésta es la decisión de fondo, porque condiciona el costo de todo lo demás.

### Opción A — Menú clásico de FPS

Pantalla 2D completa, fondo fijo o render del nivel desenfocado, lista de
botones centrada. Lo que hace cualquier shooter.

- **A favor:** barato, predecible, accesible con teclado y mando desde el primer
  día, riesgo técnico nulo.
- **En contra:** no aporta nada a la identidad del juego y es exactamente lo que
  el eje 4 quiere reemplazar. Es trabajo que después se tira.

### Opción B — Escritorio diegético en 3D (el lobby del eje 4)

El menú es la pantalla gigante del lobby, dentro del mundo. El jugador ve iconos
y los activa apuntando, disparando o con un cursor.

- **A favor:** es la visión del GDD; el menú se vuelve contenido; la
  personalización del escritorio se convierte en progresión visible.
- **En contra:** caro y con muchas preguntas abiertas todavía (§4 del documento
  madre). Poner opciones de video en una pantalla diegética es incómodo. Y
  necesita que el lobby exista antes de tener un menú funcional, con lo cual
  bloquea todo lo demás.

### Opción C — Escritorio plano (2D con lenguaje de sistema operativo)

Menú 2D a pantalla completa, pero con el vocabulario visual del juego: ventanas
con barra de título, botón de cerrar, iconos, barra de tareas. Usa los themes
`xp_theme` / `retro_theme` que ya existen. Cada pantalla de menú **es una
ventana**; el fondo es un escritorio.

- **A favor:** costo parecido al de la opción A pero con la identidad del juego;
  reutiliza themes y assets existentes; y, sobre todo, **es el ensayo del
  lobby**: los iconos, la disposición y el fondo se diseñan acá y después se
  proyectan sobre la pantalla gigante sin rediseñar el contenido, sólo el
  soporte.
- **En contra:** hay que cuidar la legibilidad (una ventana XP a 1080p se ve
  chica) y la navegación con mando dentro de una metáfora pensada para mouse.

### Comparación

| | A — Clásico | B — Diegético 3D | C — Escritorio plano |
| --- | --- | --- | --- |
| Costo inicial | Bajo | Alto | Bajo–medio |
| Identidad | Nula | Máxima | Alta |
| Riesgo técnico | Nulo | Alto | Bajo |
| Reutiliza lo que hay | Poco | Poco | Themes de ventana |
| Trabajo que sobrevive al eje 4 | Poco | Todo | Casi todo |
| Mando y teclado | Directo | A resolver | A cuidar |

**Elegida: opción C.** Da identidad sin comprometerse con el lobby, y el día que
el lobby exista la pantalla gigante puede mostrar literalmente este mismo
escritorio. La opción B queda como destino, no como punto de partida.

**Estado:** Para prototipar — armada y en uso. Se revisa al probarla.

---

## 5. Arquitectura técnica: tres caminos

### Opción 1 — Escenas independientes

Cada menú es una escena y se navega con `change_scene_to_file`. Es lo que ya se
hace con `F1`–`F4`.

- **A favor:** simple, sin estado global, cada escena se prueba sola.
- **En contra:** no sirve para pausa ni resultados, que necesitan al nivel vivo
  debajo. Y perder el nivel para volver a cargarlo hace lento el reintento, que
  es justo lo que no puede ser lento.

### Opción 2 — Autoload con pila de menús sobre un `CanvasLayer`

Un autoload (`MenuStack`, `UIManager`) mantiene su propio `CanvasLayer` y abre
los menús como hijos, apilados. Sabe pausar el árbol, mostrar el mouse y
devolver el control al cerrarse.

- **A favor:** resuelve pausa, resultados y modales sin tocar la escena de
  abajo; centraliza el control del mouse y de la pausa, que hoy está
  desparramado; el reintento es recargar el nivel, no recargar el menú.
- **En contra:** un singleton más, y hay que ser disciplinado con quién abre y
  cierra qué.

### Opción 3 — Escena raíz persistente (shell)

`main_scene` pasa a ser un contenedor que carga niveles y menús como hijos.

- **A favor:** control total del flujo, transiciones fáciles.
- **En contra:** obliga a reescribir cómo arrancan los niveles y rompe la
  costumbre de abrir `playable_level.tscn` directo desde el editor, que hoy es
  la forma normal de trabajar.

**Elegida: opción 2**, con el matiz previsto: el menú principal es una escena
propia (opción 1) y pausa, confirmaciones y resultados viven en la pila del
autoload. Es la combinación más barata que no rompe el flujo de trabajo actual:
`playable_level.tscn` se sigue abriendo directo desde el editor.

**Estado:** Para prototipar — armada y en uso.

### Deudas que hay que pagar sí o sí

Independientemente de la opción elegida:

1. **Sacar el manejo del mouse de `player_character.gd`.** Hoy `Esc` alterna la
   captura del mouse desde el jugador. En cuanto haya pausa, esa línea produce
   estados contradictorios: menú abierto con el mouse capturado, o al revés. El
   modo del mouse tiene que ser consecuencia de qué menú está abierto, y de nada
   más.
2. **Decidir qué se pausa.** `get_tree().paused = true` congela todo salvo los
   nodos con `process_mode = ALWAYS`. El menú y su sonido quedan afuera de la
   pausa; el nivel, el HUD, los temporizadores de puntaje y los bloques,
   adentro.
3. **Sacar la transición automática de `playable_level.gd`.** Hoy el nivel
   decide solo que a los 3 s arranca el siguiente. Con pantalla de resultados,
   el nivel avisa que terminó y **no** decide a dónde se va.
4. **Un lugar único para las opciones.** Sensibilidad y volumen hoy no se
   persisten. Un `ConfigFile` en `user://settings.cfg`, hermano de
   `score_records.cfg`, alcanza.

---

## 6. Reglas transversales

Propuestas, aplicables a cualquier menú:

- **`Esc` es una sola cosa:** abre la pausa si estamos jugando, cierra el menú
  de arriba de la pila si hay uno abierto. Nunca las dos cosas a la vez.
- **Reintento sin fricción:** tecla dedicada durante la partida, sin
  confirmación, y presente además en pausa y en resultados.
- **Todo salteable:** ninguna animación de menú puede impedir avanzar. El
  desglose de resultados se completa de golpe al pulsar cualquier tecla.
- **Foco de teclado siempre:** al abrir un menú, un botón queda enfocado. Es lo
  que después hace que el mando funcione gratis.
- **Nada bloquea sin decirlo:** las acciones destructivas (abandonar, borrar
  récords) piden confirmación explícita; el resto, no.
- **Sin texto quemado por todos lados.** Aunque hoy no haya localización,
  conviene tener los textos de menú juntos desde el principio.
- **El menú no asume resolución.** Contenedores y anclas, nunca posiciones a
  mano.

---

## 7. Contenido pantalla por pantalla

Borrador para prototipar. Los nombres de las opciones son provisionales.

### 7.1 Menú principal

```
JUGAR                 -> arranca el nivel actual de LevelSequence
SELECCIONAR NIVEL     -> pantalla de selección
OPCIONES              -> ventana de opciones
SALIR
```

### 7.2 Pausa

```
REANUDAR
REINTENTAR            (la misma tecla dedicada que durante la partida)
OPCIONES
ABANDONAR NIVEL       -> confirmación -> menú principal
```

Muestra además el estado de la partida en curso: nivel, sala y puntaje
acumulado.

### 7.3 Resultados de nivel

Contenido ya definido en el anexo de puntuación §9.5. Acciones:

```
REINTENTAR      SIGUIENTE NIVEL      MENÚ PRINCIPAL
```

Si no hay nivel siguiente, "SIGUIENTE NIVEL" se reemplaza por el cierre de
campaña.

### 7.4 Selección de nivel

Una entrada por nivel del catálogo, con nombre, rango máximo, porcentaje del
techo, puntaje récord, mejor tiempo e intentos. Los niveles todavía no
alcanzados se muestran o se ocultan según cómo se resuelva el desbloqueo, que es
una pregunta abierta del documento madre.

### 7.5 Opciones

| Grupo | Contenido mínimo |
| --- | --- |
| Video | Pantalla completa, resolución, límite de FPS |
| Audio | Volumen general, música, efectos |
| Controles | Sensibilidad del mouse, invertir eje Y |
| Juego | Rebind de teclas (más adelante) |

---

## 8. Plan de implementación sugerido

Fases pensadas para que cada una deje el juego jugable.

| Fase | Entrega | Estado |
| --- | --- | --- |
| **0** | Centralizar mouse y pausa; sacar `Esc` del jugador | Hecha |
| **1** | Menú de pausa con reanudar, reintentar y salir | Hecha |
| **2** | Menú principal y `main_scene` nueva; `Jugar` arranca la secuencia | Hecha |
| **3** | Pantalla de resultados; reemplaza la transición automática | Hecha |
| **4** | Selección de nivel con récords | Pendiente |
| **5** | Opciones persistentes en `user://settings.cfg` | Pendiente |
| **6** | Theme de menú propio y pulido visual del escritorio | Pendiente |
| **7** | Migración al lobby diegético | Eje 4 sin definir |

---

## 9. Lo que quedó armado (fases 0 a 3)

| Pieza | Archivo |
| --- | --- |
| Pila de menús, pausa y mouse | [`scripts/autoloads/menu_stack.gd`](../scripts/autoloads/menu_stack.gd) |
| Base de menú: velo, ventana centrada, foco | [`scripts/ui/menus/menu_screen.gd`](../scripts/ui/menus/menu_screen.gd) |
| Ventana de escritorio reutilizable (piel Windows) | [`scripts/ui/menus/desktop_window.gd`](../scripts/ui/menus/desktop_window.gd) |
| Panel de menú del juego (piel cyber) | [`scripts/ui/menus/game_panel.gd`](../scripts/ui/menus/game_panel.gd) |
| Theme del juego | [`resources/themes/game_theme.tres`](../resources/themes/game_theme.tres) |
| Menú principal / escritorio | [`scripts/ui/menus/main_menu.gd`](../scripts/ui/menus/main_menu.gd) |
| Icono de escritorio | [`scripts/ui/menus/desktop_icon.gd`](../scripts/ui/menus/desktop_icon.gd) |
| Barra de tareas | [`scripts/ui/menus/taskbar.gd`](../scripts/ui/menus/taskbar.gd) |
| Menú de inicio | [`scripts/ui/menus/start_menu_panel.gd`](../scripts/ui/menus/start_menu_panel.gd) |
| Pausa | [`scripts/ui/menus/pause_menu.gd`](../scripts/ui/menus/pause_menu.gd) |
| Confirmación | [`scripts/ui/menus/confirm_menu.gd`](../scripts/ui/menus/confirm_menu.gd) |
| Resultados de nivel | [`scripts/ui/menus/level_results.gd`](../scripts/ui/menus/level_results.gd) |
| Desglose compartido con el HUD | [`scripts/ui/score_breakdown.gd`](../scripts/ui/score_breakdown.gd) |
| Presentación del nivel | [`scripts/ui/level_intro.gd`](../scripts/ui/level_intro.gd) |
| Opciones | [`scripts/ui/menus/options_menu.gd`](../scripts/ui/menus/options_menu.gd) |
| Ajustes guardados y aplicados | [`scripts/autoloads/settings.gd`](../scripts/autoloads/settings.gd) |
| Textos en los tres idiomas | [`resources/i18n/strings.csv`](../resources/i18n/strings.csv) |
| Navegación entre escenas | `LevelSequence.play_current_level()` y compañía |

Decisiones que se tomaron mientras se armaba:

- **`Esc` abre la pausa y cierra el menú de arriba.** Ya no alterna la captura
  del mouse desde el jugador: ese estado lo decide `MenuStack` según la pila.
- **Retroceso es el reintento inmediato**, durante la partida y sin
  confirmación. `R` sigue siendo recargar.
- **El nivel avisa que terminó y no decide a dónde se va.** La transición
  automática de tres segundos se convirtió en la espera antes de los resultados,
  configurable con `results_delay`.
- **Abandonar el nivel pide confirmación; reanudar y reintentar no.**
- **El desglose del puntaje sale de un solo lugar.** El panel chico del HUD y la
  pantalla de resultados usan las mismas filas.
- **El escritorio es de verdad un escritorio.** Fondo, iconos con selección y
  doble clic, barra de tareas con botón de inicio, botón de ventana y reloj. La
  ventana del menú se puede cerrar: queda el escritorio, y la vuelven a abrir
  tanto su botón de la barra como el doble clic en `procedural.exe`.
- **Abrir el ejecutable abre la ventana, no la partida.** Dentro de la ficción,
  el doble clic lanza el programa y el programa pregunta qué hacer. Jugar es una
  decisión que se toma dentro de la ventana o desde el menú de inicio.
- **El juego se llama `procedural`.** Es el título de la ventana, el nombre del
  ejecutable en el escritorio, el del botón de la barra y el de la cabecera del
  menú de inicio. También es `application/config/name`, así que la carpeta root,
  el título de la ventana del sistema y la carpeta `user://` dicen lo mismo. Los
  récords que estaban en `user://` de `procedural-map` se copiaron a la carpeta
  nueva al hacer el cambio.
- **Los assets salen de los packs, no se dibujan.** Barra, botón de inicio,
  iconos y fondo se recortaron de `assets/_raw/WinXp.zip` a
  `assets/textures/ui/xp/`, igual que se hace con los packs de texturas.
- **La selección del escritorio es de a uno.** El icono no sabe quién más hay en
  el escritorio: avisa que lo seleccionaron y el escritorio suelta los demás. Un
  escritorio con cinco iconos encendidos a la vez no es un escritorio.
- **Los iconos sin destino redirigen, no rebotan.** Abrir `niveles`, `opciones`,
  `mi pc` o `papelera` hace parpadear el botón de la ventana en la barra, como
  una ventana que pide atención. Explorar el escritorio está permitido y siempre
  termina señalando de vuelta al juego, que es la única puerta que hoy lleva a
  algún lado. Es más honesto que un icono muerto y más amable que sacarlos.
- **El aviso dura lo que dura el motivo.** Si la ventana está cerrada, el botón
  queda encendido hasta que la abran: hay algo pendiente. Si ya está a la vista,
  alcanza con el parpadeo, porque no hay nada que abrir.
- **Windows es el menú principal; el juego es todo lo demás.** La pausa, la
  confirmación y los resultados dejaron el theme de Windows y usan el del HUD.
  Las ventanas de Windows son objetivos a los que se les dispara: un menú que se
  viera igual haría dudar al jugador entre leerlo y apuntarle. Cada estética dice
  dónde está parado, y la que aparece durante la partida es la del juego.
- **El nivel se presenta antes de dejarse ver.** Un velo con el número del nivel
  que entra, se sostiene y se va, en poco más de dos segundos. Empezar un nivel
  tiene que sentirse como empezar algo.
- **La presentación no le hace perder tiempo a nadie.** Cualquier tecla la
  saltea, y reintentar no la muestra: quien vuelve a empezar ya sabe en qué nivel
  está, y ese camino tiene que costar nada.
- **El juego habla el idioma del jugador, y uno solo.** Español, portugués e
  inglés, desde un único CSV. Antes los menús estaban en español y el HUD en
  inglés, que no era una decisión sino dos momentos distintos del proyecto.
- **Los rangos no se traducen.** `GUEST`, `ADMIN`, `ROOT` y `KERNEL` son los
  niveles de usuario del sistema operativo que el juego imita. Traducirlos
  rompería el chiste, que es lo único que los hace valer más que una letra.
- **El nivel se cierra una sola vez.** El HUD tenía un panel de resultados que
  aparecía en seco al terminar, y tres segundos después la pantalla completa
  mostraba el mismo desglose animándose. Era el mismo `ScoreBreakdown` contado
  dos veces, y la primera vez le quitaba la sorpresa a la segunda. Sobrevive la
  pantalla, que es la única que además deja elegir qué hacer con el intento.
- **Las opciones no tienen botón de aceptar.** Cada cambio se aplica y se guarda
  al hacerlo. El jugador escucha el volumen mientras lo mueve y ve el idioma
  cambiar mientras elige: pedirle que confirme algo que ya vio pasar es trabajo
  de más para él y una pantalla más para mantener.
- **Las opciones se visten según de dónde se abren.** Desde el escritorio son
  una ventana de Windows; desde la pausa, un panel del juego. Es el mismo menú
  con la piel que le pasan, así que no hay dos pantallas de opciones.
- **Las listas se eligen con flechas, no con desplegables.** Un desplegable
  arrastra un `PopupMenu` que habría que vestir en las dos pieles; con botones el
  foco viaja con el teclado sin que haya que hacer nada, que es la misma razón
  por la que los menús ya cuidan el foco.
- **El silencio silencia.** Volumen cero apaga el bus en vez de bajarlo a algo
  casi inaudible, que es lo que pasaría dejándolo en decibeles muy negativos.
- **La espera antes de los resultados no se llena con nada.** Durante esos
  segundos el HUD deja a la vista el cobro de la última cadena, que era el
  motivo por el que la espera existía.

Lo que todavía no existe: selección de nivel, récords, créditos y pantalla de
carga. Los botones que ya están en pantalla pero no hacen nada
quedan deshabilitados a propósito, para que se vea a dónde va el menú.

---

## 10. Preguntas abiertas

- ¿El menú principal muestra el nivel actual de la campaña o siempre lleva a la
  selección de nivel?
- ¿Retroceso es la tecla correcta para reintentar, o conviene una más cómoda?
- ¿Abandonar un nivel a la mitad guarda el intento en los récords o lo descarta?
- ¿La ventana de menú necesita crecer en pantallas grandes o el tamaño fijo de
  una ventana de sistema es parte de la gracia?
- ¿El fondo se queda en Bliss o el escritorio del juego pide uno propio? El pack
  trae veinte, y el eje 4 los quiere como desbloqueables.
- Los iconos decorativos ya no son mudos: avisan desde la barra. ¿Alcanza con
  eso o cada uno merece su propia ventana de sistema (una papelera vacía, un
  `mi pc` con las estadísticas de la campaña)?
- ¿La pausa congela el reloj del nivel? Debería, pero conviene decirlo.
- ¿La pantalla de resultados aparece al terminar cada nivel o sólo al cerrar la
  campaña?
- ¿Los niveles se desbloquean en orden o están todos disponibles desde el
  principio?
- ¿Queremos soporte de mando desde el principio o alcanza con teclado y mouse?
- ¿El escritorio del menú y el escritorio del lobby son el mismo dato guardado o
  son dos cosas distintas?
- ¿Qué pasa con `F1`–`F4`? ¿Se quedan como atajos de desarrollo o se convierten
  en un menú de debug?
