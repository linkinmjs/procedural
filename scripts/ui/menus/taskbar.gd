class_name Taskbar
extends NinePatchRect

## Barra de tareas del escritorio: boton de inicio, botones de ventana y reloj.
##
## Usa los recortes del pack de Windows XP, asi que la barra es la del sistema
## y no una imitacion dibujada a mano.

signal start_toggled(pressed: bool)

const TASKBAR_TEXTURE := preload("res://assets/textures/ui/xp/taskbar.png")
const START_NORMAL := preload("res://assets/textures/ui/xp/start_button.png")
const START_HOVER := preload("res://assets/textures/ui/xp/start_button_hover.png")
const START_PRESSED := preload("res://assets/textures/ui/xp/start_button_pressed.png")
const WINDOWS_LOGO := preload("res://assets/textures/ui/xp/windows_logo.png")
const THEME := preload("res://resources/themes/xp_theme.tres")

const HEIGHT := 30.0
const START_SIZE := Vector2(86.0, 28.0)
const TASK_BUTTON_SIZE := Vector2(150.0, 22.0)
const TRAY_COLOR := Color(0.10, 0.44, 0.86)
const TRAY_BORDER := Color(0.05, 0.27, 0.62)
const LABEL_COLOR := Color(1, 1, 1)

## Naranja de aviso de Windows: el boton no cambia de forma, solo se tiñe, asi
## que conserva el relieve del pack.
const ATTENTION_COLOR := Color(1.0, 0.60, 0.16)
const ATTENTION_STATES: Array[String] = ["normal", "pressed", "hover", "focus"]
const ATTENTION_BLINKS := 3
const ATTENTION_INTERVAL := 0.35
## El tween del parpadeo se guarda en el propio boton: asi muere con el y la
## barra no lleva una lista de tweens que sobreviven a sus botones.
const ATTENTION_META := "attention"

var start_button: Button

var _tasks: HBoxContainer
var _clock: Label
## Ultimo texto puesto en el reloj. Sin esto el reloj se reescribia en cada
## frame para un texto que cambia una vez por minuto.
var _clock_text := ""
## Los estilos del aviso, teñidos una sola vez: un parpadeo los pide siete
## veces y duplicar el StyleBox del theme en cada una era trabajo de mas.
var _attention_styles: Dictionary = {}


static func create() -> Taskbar:
	var bar := Taskbar.new()
	bar._build()
	return bar


func _build() -> void:
	texture = TASKBAR_TEXTURE
	patch_margin_top = 5
	patch_margin_bottom = 4
	patch_margin_left = 4
	patch_margin_right = 4
	custom_minimum_size = Vector2(0.0, HEIGHT)
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -HEIGHT
	theme = THEME

	# NinePatchRect no es un contenedor: la fila se ancla a mano sobre la barra.
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 6)
	row.offset_left = 2.0
	row.offset_right = -2.0
	add_child(row)

	row.add_child(_build_start_button())

	_tasks = HBoxContainer.new()
	_tasks.add_theme_constant_override("separation", 4)
	_tasks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tasks.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(_tasks)

	row.add_child(_build_tray())


## Boton de ventana: se ve hundido mientras esa ventana esta a la vista, igual
## que en la barra de un sistema operativo.
func add_task(text: String, icon: Texture2D, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.icon = icon
	button.toggle_mode = true
	button.button_pressed = true
	button.custom_minimum_size = TASK_BUTTON_SIZE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(on_pressed)
	_tasks.add_child(button)
	return button


## La ventana pide atencion: su boton parpadea, igual que en la barra de un
## sistema operativo. Con `hold` queda encendido despues del ultimo parpadeo,
## porque el aviso sigue pendiente hasta que alguien abra la ventana; sin
## `hold` el parpadeo se apaga solo, que es lo que corresponde cuando la
## ventana ya esta a la vista y no hay nada que abrir.
func request_attention(button: Button, hold := true) -> void:
	clear_attention(button)
	_set_attention(button, true)
	var tween := create_tween()
	for _blink in ATTENTION_BLINKS:
		tween.tween_interval(ATTENTION_INTERVAL)
		tween.tween_callback(_set_attention.bind(button, false))
		tween.tween_interval(ATTENTION_INTERVAL)
		tween.tween_callback(_set_attention.bind(button, true))
	if not hold:
		tween.tween_callback(clear_attention.bind(button))
	button.set_meta(ATTENTION_META, tween)


func clear_attention(button: Button) -> void:
	if button.has_meta(ATTENTION_META):
		var tween := button.get_meta(ATTENTION_META) as Tween
		if tween != null and tween.is_valid():
			tween.kill()
		button.remove_meta(ATTENTION_META)
	_set_attention(button, false)


func is_asking_attention(button: Button) -> bool:
	return button.has_meta(ATTENTION_META)


## El boton de ventana se dibuja hundido o suelto segun este abierta, asi que el
## aviso tiñe todos sus estados y no solo el que se ve ahora.
func _set_attention(button: Button, lit: bool) -> void:
	for state in ATTENTION_STATES:
		if lit:
			button.add_theme_stylebox_override(state, _attention_style(state))
		else:
			button.remove_theme_stylebox_override(state)


func _attention_style(state: String) -> StyleBox:
	if not _attention_styles.has(state):
		var style := THEME.get_stylebox(state, "Button").duplicate() as StyleBoxTexture
		style.modulate_color = ATTENTION_COLOR
		_attention_styles[state] = style
	return _attention_styles[state]


func _process(_delta: float) -> void:
	var now := Time.get_time_string_from_system().substr(0, 5)
	if now == _clock_text:
		return
	_clock_text = now
	_clock.text = now


func _build_start_button() -> Button:
	start_button = Button.new()
	start_button.text = "DESKTOP_START"
	start_button.icon = WINDOWS_LOGO
	start_button.toggle_mode = true
	start_button.custom_minimum_size = START_SIZE
	start_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	start_button.add_theme_font_size_override("font_size", 15)
	for state in ["normal", "hover", "pressed", "focus"]:
		start_button.add_theme_stylebox_override(state, _start_style(state))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		start_button.add_theme_color_override(state, LABEL_COLOR)
	start_button.add_theme_color_override("font_outline_color", Color(0, 0.20, 0, 0.85))
	start_button.add_theme_constant_override("outline_size", 3)
	start_button.toggled.connect(func(pressed: bool) -> void: start_toggled.emit(pressed))
	return start_button


func _start_style(state: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	match state:
		"pressed":
			style.texture = START_PRESSED
		"hover":
			style.texture = START_HOVER
		_:
			style.texture = START_NORMAL
	style.texture_margin_left = 22.0
	style.texture_margin_right = 22.0
	style.texture_margin_top = 8.0
	style.texture_margin_bottom = 8.0
	style.content_margin_left = 8.0
	style.content_margin_right = 10.0
	return style


## Bandeja del sistema: el reloj y, mas adelante, los avisos del juego.
func _build_tray() -> PanelContainer:
	var tray := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = TRAY_COLOR
	style.border_width_left = 1
	style.border_color = TRAY_BORDER
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	tray.add_theme_stylebox_override("panel", style)

	_clock = Label.new()
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock.add_theme_color_override("font_color", LABEL_COLOR)
	_clock.add_theme_font_size_override("font_size", 12)
	tray.add_child(_clock)
	return tray
