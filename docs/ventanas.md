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
| Windows XP | [`assets/UI/xp/xp_theme.tres`](../assets/UI/xp/xp_theme.tres) | `assets/UI/xp/` | [`scenes/windows/templates/xp_window_template.tscn`](../scenes/windows/templates/xp_window_template.tscn) |
| Retro gris | [`assets/UI/retro/retro_theme.tres`](../assets/UI/retro/retro_theme.tres) | `assets/UI/retro/` | [`scenes/windows/templates/retro_window_template.tscn`](../scenes/windows/templates/retro_window_template.tscn) |

Cada theme concentra fuente, botones y estilos. Cambiar el aspecto de todas las ventanas de un estilo se hace en un solo archivo. El theme retro además define `ProgressBar`, por si la ventana necesita una barra de progreso.

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

`pixels_per_meter` en el nodo raíz define cuántos píxeles del `SubViewport` equivalen a un metro. Con el valor por defecto (220), una ventana de 320 x 150 px mide 1,45 x 0,68 m en el mundo. Bajar el valor agranda la ventana; subirlo la achica y la vuelve más exigente.

El quad se redimensiona solo al iniciar. El tamaño que quedó guardado en el `QuadMesh` sirve para verla bien en el editor.

## Señales y API

```gdscript
window.zone_hit.connect(func(zone_id: String, w: WindowPanel3D) -> void: print(zone_id))
window.closed.connect(func(w: WindowPanel3D) -> void: print("cerrada"))

window.get_hit_bodies()        # todos los cuerpos disparables
window.find_hit_body("close")  # el primero con ese identificador
window.close()                 # cierre por código
```

Las ventanas todavía no reportan al `RoundController`. La integración con `TargetBlock3D` queda pendiente.

## Probar

Prueba funcional de todas las ventanas y templates:

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/window_panel_smoke_test.gd`

Vista previa renderizada en `.godot/window-preview.png`:

`Godot_v4.7-stable_win64_console.exe --path . res://tests/window_visual_smoke_test.tscn`

La vista previa necesita ventana real: con `--headless` no se puede capturar la imagen. Al agregar una ventana nueva conviene sumarla a [`tests/window_visual_smoke_test.tscn`](../tests/window_visual_smoke_test.tscn) para revisarla junto al resto.

## Origen de los assets

- `assets/UI/xp/`: recortes del atlas `WinXp/Frame/UI Theme.png` del pack WinXp de NullTale, más la fuente Tahoma incluida en ese pack. Tahoma es propiedad de Microsoft; para distribuir el juego conviene reemplazarla por una libre equivalente, y el cambio se hace sólo en los dos themes.
- `assets/UI/retro/`: archivos del pack RetroWindowsGUI, más el icono de cerrar recortado de su atlas de iconos.

Los zips originales viven en `assets/_raw/`, que no se versiona.
