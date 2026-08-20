class_name ConfirmMenu
extends MenuScreen

## Confirmacion de una accion que no se puede deshacer.
##
## Solo lo destructivo pregunta: abandonar un nivel a la mitad o borrar
## records. Reanudar y reintentar nunca pasan por aca.

var _title := "MENU_CONFIRM_TITLE"
var _message := ""
var _confirm_text := "MENU_ACCEPT"
var _on_confirm := Callable()


static func create(window_title: String, message: String, confirm_text: String, on_confirm: Callable) -> ConfirmMenu:
	var menu := ConfirmMenu.new()
	menu._title = window_title
	menu._message = message
	menu._confirm_text = confirm_text
	menu._on_confirm = on_confirm
	return menu


func _ready() -> void:
	build_window(_title)
	add_line(_message)
	add_separator()
	add_button("MENU_CANCEL", close)
	add_button(_confirm_text, _confirm)


func _confirm() -> void:
	close()
	if _on_confirm.is_valid():
		_on_confirm.call()
