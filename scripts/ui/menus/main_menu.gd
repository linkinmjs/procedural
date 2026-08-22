class_name MainMenu
extends MenuScreen

## Menu principal: el escritorio del juego.
##
## Es la escena con la que arranca el proyecto y esta armado como una sesion de
## Windows recien iniciada: fondo, iconos, barra de tareas con boton de inicio y
## una ventana abierta. Todo sale de los packs de UI que ya usan las ventanas
## disparables, asi que el menu y el juego hablan el mismo idioma visual.
##
## El escritorio es ademas el ensayo del lobby del eje 4: cuando exista la
## pantalla gigante, puede mostrar esto mismo.

const GAME_NAME := "procedural"
const WALLPAPER := preload("res://assets/textures/ui/xp/wallpaper_bliss.jpg")
## Los iconos del escritorio van a 48 px, como en un escritorio de verdad; los
## de la barra y el menu de inicio, a 32.
const ICON_STAR := preload("res://assets/textures/ui/xp/icons/star.png")
const ICON_FOLDER := preload("res://assets/textures/ui/xp/icons/folder.png")
const ICON_GEAR := preload("res://assets/textures/ui/xp/icons/gear.png")
const DESKTOP_STAR := preload("res://assets/textures/ui/xp/icons/large/star.png")
const DESKTOP_FOLDER := preload("res://assets/textures/ui/xp/icons/large/folder.png")
const DESKTOP_GEAR := preload("res://assets/textures/ui/xp/icons/large/gear.png")
const DESKTOP_COMPUTER := preload("res://assets/textures/ui/xp/icons/large/computer.png")
const DESKTOP_RECYCLE := preload("res://assets/textures/ui/xp/icons/large/recycle.png")

const DESKTOP_MARGIN := Vector2(18.0, 16.0)

var taskbar: Taskbar
var start_menu: StartMenuPanel
var task_button: Button

var _icons: VBoxContainer


func _ready() -> void:
	# El unico menu que se dibuja como Windows: aca el sistema operativo no es
	# una decoracion, es el menu. Los que aparecen durante la partida usan la
	# piel del juego.
	skin = MenuSkin.DESKTOP
	# Se llega aca desde un nivel, donde el mouse estaba capturado.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_wallpaper()
	_build_desktop_icons()
	build_window(GAME_NAME, true, Color(0, 0, 0, 0))
	_fill_window()
	_build_taskbar()
	_build_start_menu()
	focus_default()


## La ventana del menu no se cierra del todo: cerrarla deja el escritorio a la
## vista y su boton de la barra de tareas la vuelve a abrir, como en cualquier
## sistema operativo.
func close() -> void:
	_set_window_visible(false)


## Abrir el ejecutable del escritorio abre su ventana, no la partida: dentro de
## la ficcion, el doble clic lanza el programa y el programa pregunta que hacer.
func open_window() -> void:
	_set_window_visible(true)


## Las opciones son otra ventana del escritorio, asi que se dibujan con la
## piel de Windows y no con la del juego.
func open_options() -> void:
	menus().open(OptionsMenu.create(MenuSkin.DESKTOP))


func play() -> void:
	sequence().play_current_level()


func quit_game() -> void:
	get_tree().quit()


func _fill_window() -> void:
	add_line("MENU_CAMPAIGN")
	add_line(tr("MENU_LEVEL_POSITION").format({"position": sequence().get_position_text()}), true)
	add_separator()
	add_button("MENU_PLAY", play)
	add_button("MENU_SELECT_LEVEL", Callable(), false)
	add_button("MENU_OPTIONS", open_options)
	add_button("MENU_QUIT", quit_game)


func _build_wallpaper() -> void:
	var wallpaper := TextureRect.new()
	wallpaper.texture = WALLPAPER
	wallpaper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wallpaper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wallpaper.mouse_filter = Control.MOUSE_FILTER_STOP
	wallpaper.gui_input.connect(_on_desktop_input)
	add_child(wallpaper)


## Solo el ejecutable del juego abre algo. Los demas iconos tampoco se quedan
## mudos: hacen parpadear el boton de la ventana, asi que el escritorio se puede
## explorar pero siempre termina senalando de vuelta al juego. En la fase 4 esos
## mismos huecos son los niveles.
func _build_desktop_icons() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(DESKTOP_MARGIN.x))
	margin.add_theme_constant_override("margin_top", int(DESKTOP_MARGIN.y))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	_icons = VBoxContainer.new()
	_icons.add_theme_constant_override("separation", 10)
	_icons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_icons.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_icons)

	_add_icon(DESKTOP_STAR, "%s.exe" % GAME_NAME, open_window)
	_add_icon(DESKTOP_FOLDER, "DESKTOP_LEVELS", nudge_to_window)
	_add_icon(DESKTOP_GEAR, "DESKTOP_OPTIONS", open_options)
	_add_icon(DESKTOP_COMPUTER, "DESKTOP_COMPUTER", nudge_to_window)
	_add_icon(DESKTOP_RECYCLE, "DESKTOP_RECYCLE", nudge_to_window)


func _add_icon(texture: Texture2D, text: String, on_activated := Callable()) -> DesktopIcon:
	var icon := DesktopIcon.create(texture, text, on_activated)
	icon.selected.connect(_deselect_other_icons.bind(icon))
	_icons.add_child(icon)
	return icon


## Abrir un icono que todavia no lleva a ningun lado no tiene por que no hacer
## nada: la ventana del juego pide atencion desde la barra, como una que tiene
## un aviso pendiente. Si la ventana esta cerrada el aviso queda encendido hasta
## que la abran; si ya esta a la vista, alcanza con el parpadeo.
func nudge_to_window() -> void:
	taskbar.request_attention(task_button, not window.visible)


func _build_taskbar() -> void:
	taskbar = Taskbar.create()
	taskbar.start_toggled.connect(_on_start_toggled)
	add_child(taskbar)
	task_button = taskbar.add_task(GAME_NAME, ICON_STAR, _toggle_window)


## El menu de inicio cuelga sobre la barra, pegado al borde inferior izquierdo.
func _build_start_menu() -> void:
	var anchor := MarginContainer.new()
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.add_theme_constant_override("margin_left", 2)
	anchor.add_theme_constant_override("margin_bottom", int(Taskbar.HEIGHT))
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)

	start_menu = StartMenuPanel.create(GAME_NAME)
	start_menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	start_menu.size_flags_vertical = Control.SIZE_SHRINK_END
	start_menu.visible = false
	anchor.add_child(start_menu)

	start_menu.add_entry("START_PLAY", ICON_STAR, play)
	start_menu.add_entry("START_SELECT_LEVEL", ICON_FOLDER, Callable(), false)
	start_menu.add_entry("START_OPTIONS", ICON_GEAR, open_options)
	start_menu.add_shutdown(quit_game)
	# El escritorio no pasa por MenuStack.open(): se cablea aca.
	Sfx.wire_ui(self)


func _on_start_toggled(pressed: bool) -> void:
	start_menu.visible = pressed


func _close_start_menu() -> void:
	taskbar.start_button.button_pressed = false


## Clic en el fondo: se cierra el menu de inicio y se sueltan los iconos, igual
## que al hacer clic en un escritorio de verdad.
func _on_desktop_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	_close_start_menu()
	_deselect_other_icons(null)


func _deselect_other_icons(keep: DesktopIcon) -> void:
	for child in _icons.get_children():
		var icon := child as DesktopIcon
		if icon != null and icon != keep:
			icon.set_selected(false)


func _toggle_window() -> void:
	_set_window_visible(not window.visible)


func _set_window_visible(value: bool) -> void:
	window.visible = value
	task_button.set_pressed_no_signal(value)
	if value:
		# Abrir la ventana es atender el aviso: el boton deja de parpadear.
		taskbar.clear_attention(task_button)
		focus_default()
