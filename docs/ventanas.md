# Ventanas disparables

Las ventanas son los objetivos con personalidad que reemplazan a las esferas dentro de un bloque. Cada una se dibuja como UI normal de Godot dentro de un `SubViewport`, se proyecta sobre un quad en 3D y expone zonas que el jugador puede destruir apuntando: la X de la barra, un botón o un cartel.

## Piezas

- [`scripts/windows/window_panel_3d.gd`](../scripts/windows/window_panel_3d.gd): raíz de toda ventana. Escala el quad, genera los cuerpos disparables y emite `zone_hit` y `closed`.
- [`scripts/windows/window_hit_zone.gd`](../scripts/windows/window_hit_zone.gd): se adjunta a cualquier `Control` para volverlo disparable.
- [`scripts/windows/window_hit_body_3d.gd`](../scripts/windows/window_hit_body_3d.gd): cuerpo generado por cada zona. Cumple el contrato del template FPS (grupo `Target`, capa 32 y método `Hit_Successful`).

El layout manda: mover un botón en 2D recalcula su zona 3D sola. No hay coordenadas duplicadas.

## Estilos disponibles

| Estilo | Theme | Assets | Template |
| --- | --- | --- | --- |
| Windows XP | [`resources/themes/xp_theme.tres`](../resources/themes/xp_theme.tres) | `assets/textures/ui/xp/` | [`scenes/windows/templates/xp_window_template.tscn`](../scenes/windows/templates/xp_window_template.tscn) |
| Retro gris | [`resources/themes/retro_theme.tres`](../resources/themes/retro_theme.tres) | `assets/textures/ui/retro/` | [`scenes/windows/templates/retro_window_template.tscn`](../scenes/windows/templates/retro_window_template.tscn) |

Cada theme concentra fuente, botones y estilos. Cambiar el aspecto de todas las ventanas de un estilo se hace en un solo archivo. El theme retro además define `ProgressBar`, por si la ventana necesita una barra de progreso.

Estos dos themes son de las ventanas **disparables**, y el de XP lo comparte además el menú principal, que es un escritorio. Los menús que aparecen durante la partida —pausa, confirmación, resultados— usan [`game_theme.tres`](../resources/themes/game_theme.tres), que no es un estilo de ventana: es el del HUD. La razón es que a estas ventanas se les dispara, así que un menú que se viera igual sería ambiguo.

## Crear una ventana nueva

1. Duplicar el template del estilo elegido dentro de `scenes/windows/` (clic derecho en el FileSystem, **Duplicate**).
2. Renombrar el nodo raíz con el nombre de la ventana.
3. Editar los `Control` dentro de `SubViewport/Window`: textos, tamaños y controles nuevos. Se trabaja como cualquier UI 2D.
4. Marcar las zonas disparables y borrar las que no se usen.
5. Si cambia el tamaño de la ventana, ajustar `SubViewport.size` en píxeles.

El template ya trae las dos zonas habituales: la X de cerrar (`close`) y un botón de acción (`accept`).

## Zonas disparables

Una zona es cualquier `Control` con el script `window_hit_zone.gd` adjunto (**Attach Script → Load**, o arrastrarlo a la propiedad Script). Sirve sobre un `Button`, un `TextureRect` o un `Label`.

Propiedades:

- `zone_id`: identificador que viaja en la señal `zone_hit`. Puede repetirse: una ventana con X y botón de cerrar usa `close` en ambos.
- `closes_window`: si está activo, disparar la zona cierra la ventana. Desactivarlo permite zonas que sólo avisan, por ejemplo un botón trampa.

Sólo las zonas frenan el disparo. Un tiro al centro de la ventana la atraviesa sin efecto, así que la puntería importa.

## Escala

`pixels_per_meter` en el nodo raíz define cuántos píxeles del `SubViewport` equivalen a un metro. Con el valor por defecto (73), una ventana de 320 x 150 px mide 4,38 x 2,05 m en el mundo. Bajar el valor agranda la ventana; subirlo la achica y la vuelve más exigente.

El quad se redimensiona solo al iniciar. El tamaño que quedó guardado en el `QuadMesh` sirve para verla bien en el editor.

## Señales y API

```gdscript
window.zone_hit.connect(func(zone_id: String, w: WindowPanel3D) -> void: print(zone_id))
window.closed.connect(func(w: WindowPanel3D) -> void: print("cerrada"))

window.get_hit_bodies()        # todos los cuerpos disparables
window.find_hit_body("close")  # el primero con ese identificador
window.close()                 # cierre por código
```

Al recibir un disparo la ventana reporta el impacto al `RoundController` si hay uno en escena, usando `window_label` más el `zone_id` de la zona golpeada. Sin controller funciona igual.

## Familias

Una familia es una regla de juego, no una apariencia. El nivel declara cuántas ventanas de cada familia trae una capa, y [`window_catalog.gd`](../scripts/windows/window_catalog.gd) resuelve cuál escena instanciar. Una familia puede tener varias escenas: son variantes visuales de la misma regla.

| Familia | Qué cobra | Cómo se resuelve |
| --- | --- | --- |
| `normal` | Nada: es la base | Un disparo a su control |
| `popup` | La demora | El botón cuenta `SKIP 5, SKIP 4…` y no resuelve hasta llegar a cero. Al llegar escupe **una** publicidad y se queda con el SKIP disponible. Errarle al cuerpo abre otra. Tope de 7 por capa |
| `firewall` | La falta de prioridad | Un disparo. Mientras esté en pie, las demás ventanas de su capa quedan protegidas: los tiros rebotan, se tiñen de azul y no puntúan |
| `critical-error` | El disparo apurado | Tiene un control que cierra y dos que castigan, con el `zone_id` de trampa. Nacen barajados y se vuelven a barajar cada vez que se falla |
| `download` | El apuro, en las dos direcciones | Dejarla terminar muestra **Finalizar**: un disparo, 60 puntos. Cancelarla —por el botón o la X— abre la confirmación: dos disparos, 160 puntos |
| `infected-download` | Ignorarla | No se puede dejar terminar. Si la barra llega al final **cuelga el bloque y deja su pared fuera de juego**: se borra lo que hubiera en pantalla, el panel se apaga y queda una pantalla de error encendida para siempre. No llegan las capas que faltaban ni lo que las oleadas siguientes ponían **en esa pared**; las otras paredes siguen su curso. El bloque queda en pie estorbando, pero cuenta como resuelto |

Las dos descargas comparten escena y layout; la infectada se distingue por el nombre de archivo en rojo, que es la única advertencia que da.

La pantalla de error del bloque colgado vive en [`blue_screen.tscn`](../scenes/targets/blue_screen.tscn). No tiene zonas disparables ni ofrece ninguna tecla: ese es el punto, el bloque quedó inservible. El texto imita al error de sistema de los noventa sin nombrar a nadie, porque la gracia es el reconocimiento y no la cita.

El popup tiene dos variantes de espera, de 5 y 10 segundos. Son escenas distintas de la misma familia: la regla es la misma, cambia cuánto ahoga.

Las familias que el formato acepta pero todavía no tienen escena —`confirm`, `ad`, `fake-close`, `task-manager`, `corrupt-file`, `installer`— se juegan como `normal`. `WindowCatalog.is_implemented()` distingue unas de otras, y la herramienta las marca como `planned`.

Agregar una familia es escribir su escena, darle un script que extienda `WindowPanel3D` con su regla, y sumarla a `VARIANTS` en el catálogo. El formato y la herramienta ya la aceptan.

### Traer al frente

La barra de título de toda ventana es una zona: acertarle la adelanta sobre sus hermanas, como al hacer clic en un escritorio. No cierra, no puntúa y se puede repetir. Es lo que le da sentido a que las ventanas de un bloque se superpongan.

### Zonas que no puntúan

`WindowHitZone.scores` existe por una razón concreta: el puntaje cobra **cualquier** zona acertada, y una zona con un `zone_id` desconocido cae en `default_zone_value`. Una zona que no resuelve nada y no declara `scores = false` es una fuente infinita de puntos. Traer al frente y el rebote contra un escudo pasan por ahí.

### Ventanas protegidas

`WindowPanel3D.shielded` es lo que usa el firewall. Una ventana protegida se tiñe, informa el impacto como `shielded` y **rearma la zona**: el disparo que rebota no gasta el control, así que al caer el firewall se le puede volver a apuntar al mismo lugar.

## Dentro de un bloque

`TargetBlock3D` reparte las familias que declaran sus capas, resolviéndolas contra el catálogo. Para probar con esferas en vez de ventanas se apaga `uses_window_families`: ahí el bloque vuelve a repartir al azar lo que haya en `target_scenes`, respetando el tamaño de cada capa.

El bloque también expone la métrica de distribución, ya ajustada al tamaño de una ventana:

- `target_separation`: distancia mínima en metros entre dos objetivos, medida en horizontal **o** en vertical. El valor por defecto para ventanas, `Vector2(2.0, 1.0)`, es menor que su tamaño, así que **se superponen a propósito**, como ventanas apiladas en un escritorio. Subirlo por encima del tamaño de la ventana vuelve a separarlas; para esferas se usa `Vector2(1.0, 1.0)`.
- `target_padding`: margen interior del muestreo. Puede quedar chico porque cada ventana además se recorta contra los bordes del bloque según su propio tamaño, así que ninguna sobresale del panel aunque cambie la escala.

Para que el solape se vea limpio hay dos piezas:

- `stacking_depth` en el volumen adelanta cada objetivo respecto del anterior (8 cm por defecto), así dos ventanas superpuestas nunca comparten plano y no aparece z-fighting. El orden de apilado coincide con el orden de spawn, y la ventana que se ve adelante es también la que recibe el disparo.
- El material de la ventana usa transparencia por recorte (`alpha scissor`), de modo que escribe profundidad y se dibuja en el orden correcto sin depender del ordenamiento entre superficies transparentes.

Un bloque de 15 m de ancho admite unas siete posiciones, con solape entre vecinas. Si una oleada pide más objetivos de los que entran, el volumen coloca los que puede y avisa por consola.

Las oleadas, el color del panel, el movimiento y el cierre del bloque no cambian: al destruir la última ventana de una oleada aparece la siguiente, y al terminar todas el bloque se cierra.

[`level_designs/levels/nivel-ventanas.json`](../level_designs/levels/nivel-ventanas.json) es el nivel de pruebas. Está al final de `level-sequence.json`, así que se llega con F7 desde el nivel 1; para arrancar directamente ahí, mover su entrada al principio del catálogo. Tiene una sala con dos oleadas estáticas y otra con tres bloques, uno de ellos en movimiento.

## Probar

Prueba funcional de todas las ventanas y templates:

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/window_panel_smoke_test.gd`

Vista previa renderizada en `.godot/window-preview.png`:

`Godot_v4.7-stable_win64_console.exe --path . res://tests/window_visual_smoke_test.tscn`

Vista del nivel de pruebas con las ventanas dentro del bloque, en `.godot/window-level.png`:

`Godot_v4.7-stable_win64_console.exe --path . res://tests/window_level_visual_smoke_test.tscn`

La vista previa necesita ventana real: con `--headless` no se puede capturar la imagen. Al agregar una ventana nueva conviene sumarla a [`tests/window_visual_smoke_test.tscn`](../tests/window_visual_smoke_test.tscn) para revisarla junto al resto.

## Origen de los assets

- `assets/textures/ui/xp/`: recortes del atlas `WinXp/Frame/UI Theme.png` del pack WinXp de NullTale, más la fuente Tahoma incluida en ese pack (hoy en `assets/fonts/tahoma.ttf`). Tahoma es propiedad de Microsoft; para distribuir el juego conviene reemplazarla por una libre equivalente, y el cambio se hace sólo en los dos themes.
- `assets/textures/ui/retro/`: archivos del pack RetroWindowsGUI, más el icono de cerrar recortado de su atlas de iconos.

Los zips originales viven en `assets/_raw/`, que no se versiona.
