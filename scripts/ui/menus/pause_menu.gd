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
	build_window(tr("MENU_PAUSE_TITLE"))
	add_line(_level_title.to_upper())
	add_line(tr("MENU_PAUSE_STATUS").format({
		"position": _position_text,
		"score": ScoreBreakdown.thousands(_score),
	}), true)
	add_separator()
	add_button("MENU_RESUME", close)
	add_button("MENU_RETRY", retry)
	add_button("MENU_OPTIONS", _open_options)
	add_button("MENU_ABANDON", _ask_to_abandon)


## Las opciones se apilan sobre la pausa en vez de reemplazarla: al cerrarlas
## el jugador vuelve donde estaba, con el nivel todavia detenido debajo.
func _open_options() -> void:
	menus().open(OptionsMenu.create(MenuSkin.GAME))


func retry() -> void:
	menus().close_all()
	sequence().restart_current_level()


func _ask_to_abandon() -> void:
	menus().open(ConfirmMenu.create(
		tr("MENU_ABANDON_TITLE"),
		"MENU_ABANDON_BODY",
		"MENU_ABANDON_CONFIRM",
		_abandon,
	))


func _abandon() -> void:
	menus().close_all()
	sequence().return_to_main_menu()
