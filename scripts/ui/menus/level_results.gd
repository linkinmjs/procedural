class_name LevelResults
extends MenuScreen

## Resultados del nivel.
##
## El desglose aparece linea por linea porque el conteo es parte de la
## recompensa, pero cualquier tecla lo completa de golpe: nadie puede quedar
## esperando a que una animacion termine para volver a jugar. Reintentar esta a
## un boton de distancia, como pide el anexo de puntuacion.

## Segundos entre linea y linea del desglose.
const ROW_INTERVAL := 0.12
const VALUE_COLORS := {
	ScoreBreakdown.Kind.TOTAL: Color(0.55, 0.36, 0.02),
	ScoreBreakdown.Kind.RECORD: Color(0.05, 0.45, 0.16),
}

var _summary: Dictionary = {}
var _level_title := ""
var _has_next := false
var _rows: Array[Dictionary] = []
var _revealed := 0
var _elapsed := 0.0
var _rows_box: VBoxContainer
var _rank_label: Label


static func create(summary: Dictionary, level_title: String, has_next: bool) -> LevelResults:
	var menu := LevelResults.new()
	menu._summary = summary
	menu._level_title = level_title
	menu._has_next = has_next
	# Los resultados no se descartan con cancelar: se sale eligiendo que hacer
	# con el intento, no dejandolo a medias.
	menu.dismissable = false
	return menu


func _ready() -> void:
	build_window(ScoreBreakdown.title_for(_summary), false)
	add_line(_level_title.to_upper())
	add_separator()
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 2)
	_rows_box.custom_minimum_size = Vector2(360.0, 0.0)
	window.content.add_child(_rows_box)
	_rank_label = add_line(ScoreBreakdown.rank_text(_summary))
	_rank_label.add_theme_font_size_override("font_size", 15)
	_rank_label.visible = false
	add_separator()
	_build_actions()
	_rows = ScoreBreakdown.rows_for(_summary)


func _process(delta: float) -> void:
	if _revealed >= _rows.size():
		return
	_elapsed += delta
	while _elapsed >= ROW_INTERVAL and _revealed < _rows.size():
		_elapsed -= ROW_INTERVAL
		_reveal_next()


## Cualquier tecla o boton completa el desglose. Solo si ya esta completo el
## evento sigue su camino hacia los botones.
func _unhandled_input(event: InputEvent) -> void:
	if _revealed >= _rows.size():
		return
	if not (event is InputEventKey or event is InputEventMouseButton) or not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	reveal_all()


func reveal_all() -> void:
	while _revealed < _rows.size():
		_reveal_next()


func retry() -> void:
	menus().close_all()
	sequence().restart_current_level()


## Avanzar es responsabilidad de la secuencia: si no hay nivel siguiente el
## boton no existe, asi que aca no hay nada que decidir.
func advance() -> void:
	menus().close_all()
	sequence().play_next_level()


func to_main_menu() -> void:
	menus().close_all()
	sequence().return_to_main_menu()


func _build_actions() -> void:
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	window.content.add_child(actions)
	_add_action(actions, "REINTENTAR", retry)
	if _has_next and bool(_summary.get("completed", false)):
		_add_action(actions, "SIGUIENTE NIVEL", advance)
	_add_action(actions, "MENU PRINCIPAL", to_main_menu)


func _add_action(row: HBoxContainer, text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(130.0, 30.0)
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(on_pressed)
	row.add_child(button)
	if row.get_child_count() == 1:
		set_default_focus(button)


func _reveal_next() -> void:
	var row := _rows[_revealed]
	_revealed += 1
	if int(row.kind) == ScoreBreakdown.Kind.SEPARATOR:
		_rows_box.add_child(HSeparator.new())
	else:
		_rows_box.add_child(_build_row(row))
	if _revealed >= _rows.size():
		_rank_label.visible = not _rank_label.text.is_empty()


## Etiqueta que empuja a la izquierda y valor pegado a la derecha, igual que el
## panel del HUD.
func _build_row(row: Dictionary) -> HBoxContainer:
	var color: Color = VALUE_COLORS.get(int(row.kind), TEXT_COLOR)
	var line := HBoxContainer.new()
	var label := Label.new()
	label.text = str(row.label)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 13)
	line.add_child(label)
	if not str(row.value).is_empty():
		var value := Label.new()
		value.text = str(row.value)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_color_override("font_color", color)
		value.add_theme_font_size_override("font_size", 13)
		line.add_child(value)
	return line
