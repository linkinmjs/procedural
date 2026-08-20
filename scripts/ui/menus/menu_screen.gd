class_name MenuScreen
extends Control

## Base de los menus que viven en la pila de MenuStack.
##
## Resuelve lo que todos comparten: ocupar la pantalla, oscurecer lo que haya
## debajo, centrar una ventana de escritorio y dejar un boton enfocado. El foco
## no es un detalle: es lo que despues hace que el mando funcione gratis.

const MENU_THEME := preload("res://resources/themes/xp_theme.tres")
const BACKDROP_COLOR := Color(0.01, 0.03, 0.06, 0.72)
const BUTTON_MIN_SIZE := Vector2(220.0, 30.0)
const BUTTON_FONT_SIZE := 14
const TEXT_COLOR := Color(0.05, 0.05, 0.08)
const MUTED_COLOR := Color(0.28, 0.30, 0.34)

## Si el menu detiene el juego mientras esta abierto.
var pauses_game := true
## Si cancelar lo cierra. Los resultados de nivel no se descartan con Escape.
var dismissable := true

var window: DesktopWindow

var _default_focus: Control


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = MENU_THEME


## Ventana centrada sobre un velo. El velo tapa el nivel lo suficiente como para
## leer el menu sin esconder del todo lo que estaba pasando.
func build_window(window_title: String, closable := true, backdrop_color := BACKDROP_COLOR) -> DesktopWindow:
	var backdrop := ColorRect.new()
	backdrop.color = backdrop_color
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	window = DesktopWindow.create(window_title, closable)
	if closable:
		window.close_requested.connect(close)
	center.add_child(window)
	return window


func add_button(text: String, on_pressed: Callable, enabled := true) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_MIN_SIZE
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.disabled = not enabled
	if enabled:
		button.pressed.connect(on_pressed)
	else:
		# El theme de ventana no distingue el estado deshabilitado, y sin esto
		# el texto gris claro queda ilegible sobre el boton claro.
		button.add_theme_color_override("font_disabled_color", MUTED_COLOR)
	window.content.add_child(button)
	if enabled and _default_focus == null:
		_default_focus = button
	return button


func add_line(text: String, muted := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", MUTED_COLOR if muted else TEXT_COLOR)
	label.add_theme_font_size_override("font_size", 12)
	window.content.add_child(label)
	return label


func add_separator() -> void:
	window.content.add_child(HSeparator.new())


## Deja enfocado un control que el menu no creo con add_button, por ejemplo los
## botones en fila de los resultados.
func set_default_focus(control: Control) -> void:
	if _default_focus == null:
		_default_focus = control


func focus_default() -> void:
	if is_instance_valid(_default_focus):
		_default_focus.grab_focus()


func close() -> void:
	menus().close(self)


## Los autoloads se buscan desde la raiz del bucle principal y no con un
## get_node relativo: un menu que acaba de cerrarse ya salio del arbol, y
## navegar despues de cerrarse es justo lo que hacen reintentar, avanzar y
## volver al menu principal.
func menus() -> Node:
	return _autoload("MenuStack")


func sequence() -> Node:
	return _autoload("LevelSequence")


func _autoload(autoload_name: String) -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node(autoload_name)
