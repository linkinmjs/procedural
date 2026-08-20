class_name StartMenuPanel
extends PanelContainer

## Menu de inicio: cabecera azul, lista de entradas y pie con el apagado.
##
## Las mismas acciones que ofrece la ventana del menu principal, pero por donde
## un jugador que ve un escritorio va a buscarlas primero.

const THEME := preload("res://resources/themes/xp_theme.tres")
const WINDOWS_LOGO := preload("res://assets/textures/ui/xp/windows_logo.png")
const POWER_ICON := preload("res://assets/textures/ui/xp/icons/power.png")

const PANEL_WIDTH := 220.0
const HEADER_COLOR := Color(0.05, 0.30, 0.71)
const FOOTER_COLOR := Color(0.51, 0.67, 0.89)
const BODY_COLOR := Color(1, 1, 1)
const BORDER_COLOR := Color(0.05, 0.30, 0.71)
const ENTRY_TEXT := Color(0.05, 0.05, 0.08)
const ENTRY_DISABLED_TEXT := Color(0.55, 0.57, 0.60)
const ENTRY_HEIGHT := 28.0

var _entries: VBoxContainer
var _footer: HBoxContainer


static func create(header_text: String) -> StartMenuPanel:
	var panel := StartMenuPanel.new()
	panel._build(header_text)
	return panel


func _build(header_text: String) -> void:
	theme = THEME
	custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = BODY_COLOR
	style.set_border_width_all(2)
	style.border_color = BORDER_COLOR
	add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	column.add_child(_build_header(header_text))

	_entries = VBoxContainer.new()
	_entries.add_theme_constant_override("separation", 0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.add_child(_entries)
	column.add_child(margin)

	column.add_child(_build_footer())


func add_entry(text: String, icon: Texture2D, on_pressed: Callable, enabled := true) -> Button:
	var button := _make_entry(text, icon, on_pressed, enabled)
	_entries.add_child(button)
	return button


## Apagar el equipo es salir del juego: el pie del menu es el lugar donde
## cualquiera lo busca.
func add_shutdown(on_pressed: Callable) -> Button:
	var button := _make_entry("DESKTOP_SHUTDOWN", POWER_ICON, on_pressed)
	button.add_theme_color_override("font_color", Color(1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	_footer.add_child(button)
	return button


func _build_header(header_text: String) -> Control:
	var header := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = HEADER_COLOR
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	header.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	header.add_child(row)

	var logo := TextureRect.new()
	logo.texture = WINDOWS_LOGO
	logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(logo)

	var title := Label.new()
	title.text = header_text
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_font_size_override("font_size", 15)
	row.add_child(title)
	return header


func _build_footer() -> Control:
	var footer := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = FOOTER_COLOR
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	footer.add_theme_stylebox_override("panel", style)

	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_child(_footer)
	return footer


func _make_entry(text: String, icon: Texture2D, on_pressed: Callable, enabled := true) -> Button:
	var button := Button.new()
	button.text = text
	button.icon = icon
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, ENTRY_HEIGHT)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", ENTRY_TEXT)
	button.add_theme_color_override("font_hover_color", ENTRY_TEXT)
	button.add_theme_color_override("font_disabled_color", ENTRY_DISABLED_TEXT)
	button.disabled = not enabled
	if enabled and on_pressed.is_valid():
		button.pressed.connect(on_pressed)
	return button
