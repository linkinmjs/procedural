class_name LevelSelectMenu
extends MenuScreen

## Seleccion de nivel: una fila por nivel de la campaña con su record.
##
## Cada fila muestra el rango maximo, el porcentaje del techo, el puntaje
## record, el mejor tiempo y los intentos, que salen de ScoreRecords. Es el
## marcador contra uno mismo del que habla el diseño: se ve donde se esta y
## cuanto falta, sin compararse con nadie.
##
## Completar un nivel abre el siguiente; los cerrados se ven pero no se juegan.
## Los rangos nunca cierran nada: la habilidad abre expresion, no contenido.

const SCORE_SETTINGS := preload("res://resources/gameplay/score_settings.tres")
const NAME_WIDTH := 170.0
const RANK_WIDTH := 96.0
const STAT_WIDTH := 66.0
const ROW_FONT_SIZE := 11
const PLAY_SIZE := Vector2(72.0, 24.0)

var _play_buttons: Array[Button] = []
var _row_count := 0


## Filas visibles antes de que la lista pase a scroll, y alto de cada una.
const MAX_VISIBLE_ROWS := 8
const ROW_HEIGHT := 46.0


static func create(menu_skin: MenuSkin) -> LevelSelectMenu:
	var menu := LevelSelectMenu.new()
	menu.skin = menu_skin
	return menu


func _ready() -> void:
	build_window(tr("MENU_SELECT_LEVEL"))
	var seq := sequence()
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	header.add_child(_build_header())
	header.add_child(HSeparator.new())
	content.add_child(header)
	# Con la campaña entera la lista no entra en pantalla: las filas van en un
	# scroll que sigue al foco, y la cabecera queda fija arriba.
	if seq.get_level_count() > MAX_VISIBLE_ROWS:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(0.0, ROW_HEIGHT * MAX_VISIBLE_ROWS)
		scroll.follow_focus = true
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(rows)
		content.add_child(scroll)
	else:
		content.add_child(rows)
	for index in seq.get_level_count():
		rows.add_child(_build_row(index))
		_row_count += 1
	add_separator()
	add_button("MENU_BACK", close)
	for button in _play_buttons:
		if not button.disabled:
			set_default_focus(button)
			break


func row_count() -> int:
	return _row_count


func play_buttons() -> Array[Button]:
	return _play_buttons


func play(index: int) -> void:
	var seq := sequence()
	if not seq.is_unlocked(index):
		return
	menus().close_all()
	seq.select_level(index)
	seq.play_current_level()


func _build_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_cell(tr("SELECT_LEVEL_HEADER"), NAME_WIDTH, muted_color()))
	row.add_child(_cell(tr("SELECT_RANK"), RANK_WIDTH, muted_color()))
	row.add_child(_cell(tr("SELECT_CEILING"), STAT_WIDTH, muted_color()))
	row.add_child(_cell(tr("SELECT_RECORD"), STAT_WIDTH, muted_color()))
	row.add_child(_cell(tr("SELECT_TIME"), STAT_WIDTH, muted_color()))
	row.add_child(_cell(tr("SELECT_ATTEMPTS"), STAT_WIDTH, muted_color()))
	row.add_child(_cell("", PLAY_SIZE.x, muted_color()))
	return row


func _build_row(index: int) -> HBoxContainer:
	var seq := sequence()
	var unlocked := bool(seq.is_unlocked(index))
	var completed := bool(seq.is_completed(index))
	var current := index == int(seq.get_current_index())
	var color := text_color() if unlocked else muted_color()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_text := tr("SELECT_ROW").format({"number": index + 1, "name": str(seq.get_level_name(index))})
	if completed:
		name_text = "%s %s" % [name_text, tr("SELECT_COMPLETED")]
	var name_cell := _cell(name_text, NAME_WIDTH, color)
	if current:
		name_cell.add_theme_font_size_override("font_size", ROW_FONT_SIZE + 1)
	row.add_child(name_cell)

	if not unlocked:
		var hint := _cell(tr("SELECT_LOCKED_HINT"), RANK_WIDTH + STAT_WIDTH * 4.0 + 32.0, muted_color())
		row.add_child(hint)
	else:
		var record := ScoreRecords.load_record(str(seq.get_level_id(index)))
		var stale := record.has("formula_version") and int(record.formula_version) != SCORE_SETTINGS.formula_version
		var stat_color := muted_color() if stale else color
		row.add_child(_cell(_rank_text(record, stale), RANK_WIDTH, stat_color))
		row.add_child(_cell(_ceiling_text(record), STAT_WIDTH, stat_color))
		row.add_child(_cell(_score_text(record), STAT_WIDTH, stat_color))
		row.add_child(_cell(_time_text(record), STAT_WIDTH, stat_color))
		row.add_child(_cell(str(int(record.get("attempts", 0))), STAT_WIDTH, color))

	var button := Button.new()
	button.text = "MENU_PLAY"
	button.custom_minimum_size = PLAY_SIZE
	button.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	button.disabled = not unlocked
	if unlocked:
		button.pressed.connect(play.bind(index))
	elif skin == MenuSkin.DESKTOP:
		button.add_theme_color_override("font_disabled_color", DESKTOP_MUTED_COLOR)
	_play_buttons.append(button)
	row.add_child(button)
	return row


func _cell(text: String, width: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 0.0)
	label.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	return label


func _rank_text(record: Dictionary, stale: bool) -> String:
	if not record.has("ratio"):
		return tr("SELECT_NONE")
	var rank := SCORE_SETTINGS.rank_for_ratio(float(record.ratio))
	var text := "%s · %s" % [str(rank.letter), str(rank.label)]
	return "%s%s" % [text, tr("SELECT_OLD_FORMULA")] if stale else text


func _ceiling_text(record: Dictionary) -> String:
	if not record.has("ratio"):
		return tr("SELECT_NONE")
	return tr("SELECT_CEILING_VALUE").format({"percent": roundi(float(record.ratio) * 100.0)})


func _score_text(record: Dictionary) -> String:
	if not record.has("score"):
		return tr("SELECT_NONE")
	return ScoreBreakdown.thousands(int(record.score))


func _time_text(record: Dictionary) -> String:
	if not record.has("time") or float(record.time) <= 0.0:
		return tr("SELECT_NONE")
	var total := roundi(float(record.time))
	return tr("SELECT_TIME_VALUE").format({"minutes": "%02d" % (total / 60), "seconds": "%02d" % (total % 60)})
