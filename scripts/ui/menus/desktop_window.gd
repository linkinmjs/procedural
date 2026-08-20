class_name DesktopWindow
extends MarginContainer

## Ventana de escritorio para los menus.
##
## Es el mismo lenguaje visual que las ventanas disparables del juego, con los
## mismos assets y el mismo theme: los menus son ventanas de un sistema
## operativo y el fondo es un escritorio. El dia que exista el lobby, la
## pantalla gigante puede mostrar este mismo escritorio sin rediseñarlo.

signal close_requested

const THEME := preload("res://resources/themes/xp_theme.tres")
const BODY_TEXTURE := preload("res://assets/textures/ui/xp/window_body.png")
const TITLE_BAR_TEXTURE := preload("res://assets/textures/ui/xp/titlebar_active.png")
const CLOSE_TEXTURE := preload("res://assets/textures/ui/xp/close_button.png")
## Alto de la barra en la textura original. Estirarla se ve mal, asi que la
## barra mantiene su alto y la ventana crece hacia abajo.
const TITLE_BAR_HEIGHT := 29.0
const TITLE_COLOR := Color(1, 1, 1)
const CONTENT_SEPARATION := 8

## Donde se cuelga el contenido de cada menu.
var content: VBoxContainer

var _title_label: Label
var _close_button: TextureButton


static func create(window_title: String, closable := true) -> DesktopWindow:
	var window := DesktopWindow.new()
	window.setup(window_title, closable)
	return window


func setup(window_title: String, closable := true) -> void:
	theme = THEME
	add_theme_constant_override("margin_left", 0)
	add_theme_constant_override("margin_top", 0)
	add_theme_constant_override("margin_right", 0)
	add_theme_constant_override("margin_bottom", 0)

	var body := NinePatchRect.new()
	body.texture = BODY_TEXTURE
	body.patch_margin_left = 5
	body.patch_margin_top = 5
	body.patch_margin_right = 5
	body.patch_margin_bottom = 5
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 0)
	add_child(layout)
	layout.add_child(_build_title_bar(window_title, closable))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(margin)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", CONTENT_SEPARATION)
	margin.add_child(content)


func set_title(window_title: String) -> void:
	if _title_label != null:
		_title_label.text = window_title


func _build_title_bar(window_title: String, closable: bool) -> Control:
	var bar := NinePatchRect.new()
	bar.texture = TITLE_BAR_TEXTURE
	bar.patch_margin_left = 7
	bar.patch_margin_top = 8
	bar.patch_margin_right = 7
	bar.patch_margin_bottom = 2
	bar.custom_minimum_size = Vector2(0.0, TITLE_BAR_HEIGHT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# NinePatchRect no es un contenedor, asi que la fila de la barra se ancla a
	# mano en vez de dejarsela a un layout.
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 9.0
	row.offset_right = -6.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)

	_title_label = Label.new()
	_title_label.text = window_title
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	_title_label.add_theme_font_size_override("font_size", 13)
	row.add_child(_title_label)

	if not closable:
		return bar
	_close_button = TextureButton.new()
	_close_button.texture_normal = CLOSE_TEXTURE
	_close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close_button.tooltip_text = "MENU_CLOSE_TOOLTIP"
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	row.add_child(_close_button)
	return bar
