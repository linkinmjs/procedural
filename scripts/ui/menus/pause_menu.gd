class_name PauseMenu
extends MenuScreen

## Pausa del nivel.
##
## Reintentar tambien vive aca, pero no es su motivo de existir: reiniciar tiene
## una tecla dedicada durante la partida justamente para no obligar a abrir un
## menu. La pausa existe para lo demas: mirar como viene el intento, abandonar
## el nivel y, mas adelante, las opciones.

var _level_title := ""
var _position_text := ""
var _score := 0


static func create(level_title: String, position_text: String, score: int) -> PauseMenu:
	var menu := PauseMenu.new()
	menu._level_title = level_title
	menu._position_text = position_text
	menu._score = score
	return menu


func _ready() -> void:
	build_window("Pausa")
	add_line(_level_title.to_upper())
	add_line("NIVEL %s     PUNTAJE %s" % [_position_text, ScoreBreakdown.thousands(_score)], true)
	add_separator()
	add_button("REANUDAR", close)
	add_button("REINTENTAR", retry)
	add_button("OPCIONES", Callable(), false)
	add_button("ABANDONAR NIVEL", _ask_to_abandon)


func retry() -> void:
	menus().close_all()
	sequence().restart_current_level()


func _ask_to_abandon() -> void:
	menus().open(ConfirmMenu.create(
		"Abandonar nivel",
		"Se pierde el intento en curso.",
		"ABANDONAR",
		_abandon,
	))


func _abandon() -> void:
	menus().close_all()
	sequence().return_to_main_menu()
