class_name MenuScreen
extends Control

## Base de los menus que viven en la pila de MenuStack.
##
## Resuelve lo que todos comparten: ocupar la pantalla, oscurecer lo que haya
## debajo, centrar el marco del menu y dejar un boton enfocado. El foco no es un
## detalle: es lo que despues hace que el mando funcione gratis.
##
## Cada menu elige con que piel se dibuja. La del escritorio es la de Windows,
## porque el menu principal ES un escritorio; la del juego es la del HUD del
## nivel. Los menus que aparecen durante la partida usan la del juego para no
## confundirse con las ventanas disparables, que son objetivos y no interfaz.

## DESKTOP viste el menu como una ventana de Windows; GAME, como un panel del
## HUD. Es lo unico que hay que elegir para cambiar de lenguaje visual.
enum MenuSkin {GAME, DESKTOP}

const DESKTOP_THEME := preload("res://resources/themes/xp_theme.tres")
const GAME_THEME := preload("res://resources/themes/game_theme.tres")
const BACKDROP_COLOR := Color(0.01, 0.03, 0.06, 0.72)
const BUTTON_MIN_SIZE := Vector2(220.0, 30.0)
const BUTTON_FONT_SIZE := 14
const DESKTOP_TEXT_COLOR := Color(0.05, 0.05, 0.08)
const DESKTOP_MUTED_COLOR := Color(0.28, 0.30, 0.34)
const GAME_TEXT_COLOR := Color(0.86, 0.96, 1.0)
const GAME_MUTED_COLOR := Color(0.55, 0.68, 0.78)

## Si el menu detiene el juego mientras esta abierto.
var pauses_game := true
## Si cancelar lo cierra. Los resultados de nivel no se descartan con Escape.
var dismissable := true
## Se fija antes de build_window(). El default es el del juego: los menus de
## Windows son la excepcion, y son uno solo.
var skin := MenuSkin.GAME

## El marco del menu: una ventana de escritorio o un panel del juego, segun la
## piel. Los dos ofrecen la misma interfaz.
var window: Control
## Donde va el contenido del menu, ya adentro del marco.
var content: VBoxContainer

var _default_focus: Control


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Marco centrado sobre un velo. El velo tapa el nivel lo suficiente como para
## leer el menu sin esconder del todo lo que estaba pasando.
func build_window(window_title: String, closable := true, backdrop_color := BACKDROP_COLOR) -> Control:
	theme = DESKTOP_THEME if skin == MenuSkin.DESKTOP else GAME_THEME

	var backdrop := ColorRect.new()
	backdrop.color = backdrop_color
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Un velo transparente no es un velo: el menu principal lo usa solo para
	# centrar su ventana y lo que hay debajo tiene que seguir recibiendo clics.
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE if backdrop_color.a <= 0.0 else Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	if skin == MenuSkin.DESKTOP:
		var desktop_window := DesktopWindow.create(window_title, closable)
		content = desktop_window.content
		window = desktop_window
		if closable:
			desktop_window.close_requested.connect(close)
	else:
		var game_panel := GamePanel.create(window_title, closable)
		content = game_panel.content
		window = game_panel
		if closable:
			game_panel.close_requested.connect(close)
	center.add_child(window)
	return window


func set_window_title(window_title: String) -> void:
	if window is DesktopWindow:
		(window as DesktopWindow).set_title(window_title)
	elif window is GamePanel:
		(window as GamePanel).set_title(window_title)


func add_button(text: String, on_pressed: Callable, enabled := true) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_MIN_SIZE
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.disabled = not enabled
	if enabled:
		button.pressed.connect(on_pressed)
	elif skin == MenuSkin.DESKTOP:
		# El theme de Windows no distingue el estado deshabilitado, y sin esto
		# el texto gris claro queda ilegible sobre el boton claro. El del juego
		# ya lo resuelve en el theme.
		button.add_theme_color_override("font_disabled_color", DESKTOP_MUTED_COLOR)
	content.add_child(button)
	if enabled and _default_focus == null:
		_default_focus = button
	return button


func add_line(text: String, muted := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", muted_color() if muted else text_color())
	label.add_theme_font_size_override("font_size", 12)
	content.add_child(label)
	return label


func add_separator() -> void:
	content.add_child(HSeparator.new())


## Los colores del texto salen de la piel: el panel del juego es oscuro y el de
## Windows claro, asi que el mismo gris no sirve para los dos.
func text_color() -> Color:
	return DESKTOP_TEXT_COLOR if skin == MenuSkin.DESKTOP else GAME_TEXT_COLOR


func muted_color() -> Color:
	return DESKTOP_MUTED_COLOR if skin == MenuSkin.DESKTOP else GAME_MUTED_COLOR


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


func settings() -> GameSettings:
	return _autoload("Settings") as GameSettings


func _autoload(autoload_name: String) -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node(autoload_name)
