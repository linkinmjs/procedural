class_name GamePanel
extends CyberPanel

## Panel de menu para lo que pasa dentro de la partida: pausa, confirmacion y
## resultados.
##
## Es el gemelo de DesktopWindow, con la misma interfaz, pero vestido con el
## lenguaje del juego en vez del de Windows: el mismo panel oscuro de esquinas
## recortadas y acento cian que ya usa el HUD del nivel.
##
## La separacion no es capricho. Las ventanas de Windows son objetivos a los que
## se les dispara, y el escritorio es el menu principal; si la pausa se viera
## igual, el jugador no sabria si tiene que leerla o dispararle. Cada estetica
## dice donde esta parado: Windows es el sistema, cyber es el juego.

signal close_requested

const THEME := preload("res://resources/themes/game_theme.tres")
## Colores desde HudStyle: el marco de la pausa y los resultados es la misma
## interfaz que el HUD del nivel.
const HEADER_COLOR := HudStyle.ACCENT
const HEADER_FONT_SIZE := 11
const CLOSE_COLOR := HudStyle.ACCENT
const CLOSE_HOVER_COLOR := Color(1, 0.3, 0.36, 1)
const CONTENT_SEPARATION := 8
## El _draw de CyberPanel apoya su marca sobre el borde superior, asi que el
## contenido arranca mas abajo para no pisarla.
const PADDING := Vector2(18.0, 16.0)

## Donde se cuelga el contenido de cada menu.
var content: VBoxContainer

var _title_label: Label


static func create(panel_title: String, closable := true) -> GamePanel:
	var panel := GamePanel.new()
	panel.setup(panel_title, closable)
	return panel


func setup(panel_title: String, closable := true) -> void:
	theme = THEME
	accent_color = HEADER_COLOR

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(PADDING.x))
	margin.add_theme_constant_override("margin_top", int(PADDING.y))
	margin.add_theme_constant_override("margin_right", int(PADDING.x))
	margin.add_theme_constant_override("margin_bottom", int(PADDING.y))
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", CONTENT_SEPARATION)
	margin.add_child(layout)
	layout.add_child(_build_header(panel_title, closable))
	layout.add_child(HSeparator.new())

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", CONTENT_SEPARATION)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(content)


func set_title(panel_title: String) -> void:
	if _title_label != null:
		_title_label.text = _header_text(panel_title)


## La cabecera imita la de los paneles del HUD, con las dos barras delante del
## titulo, para que la pausa se lea como parte de la misma interfaz.
func _build_header(panel_title: String, closable: bool) -> Control:
	var row := HBoxContainer.new()

	_title_label = Label.new()
	_title_label.text = _header_text(panel_title)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", HEADER_COLOR)
	_title_label.add_theme_font_size_override("font_size", HEADER_FONT_SIZE)
	row.add_child(_title_label)

	if closable:
		row.add_child(_build_close_button())
	return row


func _build_close_button() -> Button:
	var button := Button.new()
	button.text = "X"
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", HEADER_FONT_SIZE)
	button.add_theme_color_override("font_color", CLOSE_COLOR)
	button.add_theme_color_override("font_hover_color", CLOSE_HOVER_COLOR)
	button.add_theme_color_override("font_pressed_color", CLOSE_HOVER_COLOR)
	button.pressed.connect(func() -> void: close_requested.emit())
	return button


func _header_text(panel_title: String) -> String:
	return "// %s" % panel_title
