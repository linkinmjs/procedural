extends CanvasLayer

## Pila de menus del juego.
##
## Los menus se abren encima de lo que haya en pantalla en vez de reemplazarlo:
## la pausa y los resultados necesitan el nivel vivo debajo para que reintentar
## sea recargar la escena y no volver a construir el menu.
##
## Es tambien el unico lugar que decide si el arbol esta pausado y como esta el
## mouse. Antes esa decision vivia repartida entre el jugador y cada escena, y
## eso producia estados contradictorios: menu abierto con el mouse capturado.
##
## El diseño esta en docs/gdd_atractivo_y_progresion_ANEXO_menus.md.

signal menu_opened(menu: MenuScreen)
signal menu_closed(menu: MenuScreen)

## Por encima de los HUD del nivel, que viven en capas bajas.
const MENU_LAYER := 128

var _stack: Array[MenuScreen] = []
## Modo del mouse previo al primer menu de la pila. El nivel lo quiere
## capturado y el menu principal visible, asi que no se puede asumir ninguno.
var _mouse_mode_before := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	layer = MENU_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


## Cancelar cierra el menu de arriba, nunca la pila entera. Los menus que no se
## pueden descartar, como los resultados, se declaran no dismissable.
func _unhandled_input(event: InputEvent) -> void:
	if _stack.is_empty():
		return
	if not event.is_action_pressed("pause") and not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if top().dismissable:
		Sfx.play("ui_back")
		close_top()


func open(menu: MenuScreen) -> MenuScreen:
	if menu == null:
		return null
	_remember_mouse_mode()
	_stack.append(menu)
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu)
	_apply_state()
	menu.focus_default()
	# Los botones del menu ya existen (los construye en su _ready). Se cablean
	# despues del foco inicial, para que abrir el menu no suene como un hover.
	Sfx.wire_ui(menu)
	menu_opened.emit(menu)
	return menu


func close(menu: MenuScreen) -> void:
	if menu == null or not _stack.has(menu):
		return
	_stack.erase(menu)
	remove_child(menu)
	menu.queue_free()
	_apply_state()
	menu_closed.emit(menu)


func close_top() -> void:
	if _stack.is_empty():
		return
	close(top())


func close_all() -> void:
	while not _stack.is_empty():
		close_top()


func top() -> MenuScreen:
	return _stack.back() if not _stack.is_empty() else null


func is_open() -> bool:
	return not _stack.is_empty()


## Busca un menu abierto por su script. Sirve para no abrir dos pausas y para
## que las pruebas encuentren lo que quedo en pantalla.
func find(script_path: String) -> MenuScreen:
	for menu in _stack:
		var menu_script := menu.get_script() as Script
		if menu_script != null and menu_script.resource_path == script_path:
			return menu
	return null


func _remember_mouse_mode() -> void:
	if _stack.is_empty():
		_mouse_mode_before = Input.get_mouse_mode()


## La pausa y el mouse son consecuencia de la pila, no de quien la toco: con
## menus apilados alcanza que uno pida pausa para que el arbol siga detenido.
func _apply_state() -> void:
	var wants_pause := false
	for menu in _stack:
		wants_pause = wants_pause or menu.pauses_game
	get_tree().paused = wants_pause
	if _stack.is_empty():
		Input.set_mouse_mode(_mouse_mode_before)
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
