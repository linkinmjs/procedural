class_name NoticeBalloon
extends PanelContainer

## Globo de aviso: un logro nuevo o una subida de nivel.
##
## Se viste segun donde aparece. En el escritorio es el globo amarillo de la
## bandeja de Windows, pegado a la barra de tareas; durante la partida es un
## panel del HUD, abajo y al centro, donde no pisa ni los vitales ni el log.
## Se queda unos segundos y se va; un clic lo cierra antes.

signal dismissed

const WIDTH := 300.0
const ICON_SIZE := Vector2(32.0, 32.0)
const DESKTOP_THEME := preload("res://resources/themes/xp_theme.tres")
const GAME_THEME := preload("res://resources/themes/game_theme.tres")
const DESKTOP_BG := Color(1.0, 1.0, 0.88)
const DESKTOP_BORDER := Color(0.35, 0.35, 0.35)
const DESKTOP_TITLE := Color(0.0, 0.0, 0.0)
const DESKTOP_BODY := Color(0.15, 0.15, 0.18)

var desktop := false

var _leaving := false


static func create(title: String, body: String, icon: Texture2D, on_desktop: bool) -> NoticeBalloon:
	var balloon := NoticeBalloon.new()
	balloon.desktop = on_desktop
	balloon._build(title, body, icon)
	return balloon


func _build(title: String, body: String, icon: Texture2D) -> void:
	theme = DESKTOP_THEME if desktop else GAME_THEME
	custom_minimum_size = Vector2(WIDTH, 0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = DESKTOP_BG if desktop else HudStyle.PANEL_BG
	style.border_color = DESKTOP_BORDER if desktop else HudStyle.PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4 if desktop else 0)
	style.content_margin_left = 10.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	if icon != null:
		var image := TextureRect.new()
		image.texture = icon
		image.custom_minimum_size = ICON_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(image)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)

	var title_label := Label.new()
	title_label.text = title if desktop else "// %s" % title
	title_label.add_theme_font_size_override("font_size", 12 if desktop else 11)
	title_label.add_theme_color_override("font_color", DESKTOP_TITLE if desktop else HudStyle.ACCENT)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_label)

	var body_label := Label.new()
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 11 if desktop else 12)
	body_label.add_theme_color_override("font_color", DESKTOP_BODY if desktop else HudStyle.TEXT_PRIMARY)
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body_label)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	accept_event()
	play_out()


## Entra con un fundido; el deslizamiento lo pone quien lo coloca, porque la
## posicion la gobierna un contenedor.
func play_in() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, HudStyle.DUR_SLIDE_IN)


## Se va con un fundido y avisa cuando termino, para que entre el siguiente.
func play_out() -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, HudStyle.DUR_HIDE)
	tween.tween_callback(func() -> void:
		dismissed.emit()
		queue_free()
	)
