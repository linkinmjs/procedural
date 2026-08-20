class_name DesktopIcon
extends VBoxContainer

## Icono del escritorio: imagen arriba, etiqueta abajo.
##
## Se comporta como el de un sistema operativo: un clic lo selecciona y el doble
## clic lo ejecuta. El icono no sabe quien mas hay en el escritorio, asi que
## avisa cada vez que lo seleccionan y el escritorio se encarga de soltar los
## demas: la seleccion es de a uno, como en cualquier sistema operativo.
##
## En la fase 4 estos mismos iconos representan los niveles de la campaña.

signal selected
signal activated

const ICON_SIZE := Vector2(48.0, 48.0)
const CELL_WIDTH := 96.0
const LABEL_COLOR := Color(1, 1, 1)
const LABEL_SHADOW := Color(0, 0, 0, 0.75)
const SELECTED_COLOR := Color(0.05, 0.28, 0.75, 0.55)

var _selected := false
var _on_activated := Callable()
var _selection: ColorRect


static func create(texture: Texture2D, text: String, on_activated := Callable()) -> DesktopIcon:
	var icon := DesktopIcon.new()
	icon._on_activated = on_activated
	icon._build(texture, text)
	return icon


func _build(texture: Texture2D, text: String) -> void:
	custom_minimum_size = Vector2(CELL_WIDTH, 0.0)
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var image := TextureRect.new()
	image.texture = texture
	image.custom_minimum_size = ICON_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)

	var label_box := Control.new()
	label_box.custom_minimum_size = Vector2(CELL_WIDTH, 16.0)
	label_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label_box)

	_selection = ColorRect.new()
	_selection.color = SELECTED_COLOR
	_selection.set_anchors_preset(Control.PRESET_FULL_RECT)
	_selection.visible = false
	_selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_box.add_child(_selection)

	var label := Label.new()
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", LABEL_COLOR)
	label.add_theme_color_override("font_shadow_color", LABEL_SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_font_size_override("font_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_box.add_child(label)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	accept_event()
	if click.double_click:
		activate()
		return
	select()


func select() -> void:
	set_selected(true)
	selected.emit()


func activate() -> void:
	select()
	activated.emit()
	if _on_activated.is_valid():
		_on_activated.call()


func set_selected(value: bool) -> void:
	_selected = value
	_selection.visible = value


func is_selected() -> bool:
	return _selected
