class_name MainMenu
extends MenuScreen

## Menu principal: el escritorio del juego.
##
## Es la escena con la que arranca el proyecto. Por ahora el escritorio esta
## vacio y todo pasa por una ventana, pero el fondo y la barra de tareas ya
## estan puestos para lo que viene: los iconos de nivel de la fase 4 y, mas
## adelante, el escritorio personalizable del lobby.

const WALLPAPER_TOP := Color(0.05, 0.13, 0.20)
const WALLPAPER_BOTTOM := Color(0.02, 0.05, 0.09)
const TASKBAR_COLOR := Color(0.03, 0.09, 0.14, 0.95)
const TASKBAR_TEXT_COLOR := Color(0.62, 0.86, 0.95)
const TASKBAR_HEIGHT := 30.0

var _clock: Label


func _ready() -> void:
	# Se llega aca desde un nivel, donde el mouse estaba capturado.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_wallpaper()
	build_window("procedural-map", false, Color(0, 0, 0, 0))
	_build_taskbar()

	var sequence_node := sequence()
	add_line("CAMPAÑA")
	add_line("NIVEL %s" % sequence_node.get_position_text(), true)
	add_separator()
	add_button("JUGAR", _play)
	add_button("SELECCIONAR NIVEL", Callable(), false)
	add_button("OPCIONES", Callable(), false)
	add_button("SALIR", _quit)
	focus_default()


func _process(_delta: float) -> void:
	if _clock != null:
		_clock.text = Time.get_time_string_from_system().substr(0, 5)


## Jugar arranca donde quedo la campaña. Elegir otro nivel es trabajo del
## selector, que todavia no existe.
func _play() -> void:
	sequence().play_current_level()


func _quit() -> void:
	get_tree().quit()


func _build_wallpaper() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, WALLPAPER_TOP)
	gradient.set_color(1, WALLPAPER_BOTTOM)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	var wallpaper := TextureRect.new()
	wallpaper.texture = texture
	wallpaper.stretch_mode = TextureRect.STRETCH_SCALE
	wallpaper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wallpaper)


func _build_taskbar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -TASKBAR_HEIGHT
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = TASKBAR_COLOR
	style.border_width_top = 1
	style.border_color = TASKBAR_TEXT_COLOR
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	bar.add_theme_stylebox_override("panel", style)
	add_child(bar)

	var row := HBoxContainer.new()
	bar.add_child(row)
	var title := Label.new()
	title.text = "procedural-map"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", TASKBAR_TEXT_COLOR)
	row.add_child(title)

	_clock = Label.new()
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock.add_theme_color_override("font_color", TASKBAR_TEXT_COLOR)
	row.add_child(_clock)
