class_name MyComputerMenu
extends MenuScreen

## Mi PC: la vitrina del jugador.
##
## Nivel y barra de XP arriba, despues las estadisticas acumuladas, la grilla
## de logros (ganados y por ganar) y los ultimos eventos de XP. Es la pantalla
## que le da sentido a todo lo demas: un logro que nadie ve no vale nada, y un
## contador que nadie puede mirar no motiva a subir.
##
## Es una ventana del escritorio, asi que siempre se dibuja con la piel de
## Windows.

const BADGE_COLUMNS := 6
const STATS_COLUMNS := 4
const LOG_LINES := 8
const SCROLL_SIZE := Vector2(560.0, 360.0)
const SECTION_FONT_SIZE := 12
const ROW_FONT_SIZE := 11

var _profile: GameProfile
var _badge_tiles: Array[BadgeTile] = []


static func create() -> MyComputerMenu:
	var menu := MyComputerMenu.new()
	menu.skin = MenuSkin.DESKTOP
	return menu


func _ready() -> void:
	_profile = profile()
	build_window(tr("DESKTOP_COMPUTER"))
	if _profile == null:
		add_line(tr("PROFILE_EMPTY_LOG"), true)
		add_button("MENU_BACK", close)
		return
	content.add_child(ProfileHeader.create(_profile, true, text_color(), muted_color()))
	add_line(tr("PROFILE_XP_TOTAL").format({"xp": ScoreBreakdown.thousands(_profile.get_xp())}), true)
	add_separator()

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = SCROLL_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)

	_add_section(column, tr("PROFILE_SECTION_STATS"))
	column.add_child(_build_stats())
	_add_section(column, "%s   %s" % [tr("PROFILE_SECTION_BADGES"), tr("PROFILE_BADGES_COUNT").format({
		"earned": _profile.badge_count(),
		"total": AchievementCatalog.all().size(),
	})])
	column.add_child(_build_badges())
	_add_section(column, tr("PROFILE_SECTION_LOG"))
	column.add_child(_build_log())

	add_separator()
	add_button("MENU_BACK", close)


func badge_tiles() -> Array[BadgeTile]:
	return _badge_tiles


func _add_section(parent: Control, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", SECTION_FONT_SIZE)
	label.add_theme_color_override("font_color", text_color())
	parent.add_child(label)


## Las estadisticas son el tablero del jugador y tambien el del diseñador: lo
## que el juego cuenta es lo que despues se puede ajustar.
func _build_stats() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = STATS_COLUMNS
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 3)
	var shots := int(_profile.get_stat("shots_fired"))
	var hits := int(_profile.get_stat("shots_hit"))
	var accuracy := "%.1f%%" % (float(hits) / float(shots) * 100.0) if shots > 0 else tr("SELECT_NONE")
	var rows := [
		["PROFILE_STAT_RUNS", str(int(_profile.get_stat("runs_started")))],
		["PROFILE_STAT_COMPLETED", tr("PROFILE_COMPLETED_VALUE").format({"done": _profile.completed_count(), "total": sequence().get_level_count()})],
		["PROFILE_STAT_WINDOWS", str(int(_profile.get_stat("windows_closed")))],
		["PROFILE_STAT_X_CLOSES", str(int(_profile.get_stat("closed_close")))],
		["PROFILE_STAT_SHOTS", str(shots)],
		["PROFILE_STAT_ACCURACY", accuracy],
		["PROFILE_STAT_BEST_CHAIN", str(int(_profile.get_stat("best_chain")))],
		["PROFILE_STAT_BEST_MULT", "x%.1f" % float(_profile.get_stat("best_multiplier"))],
		["PROFILE_STAT_ROOMS", str(int(_profile.get_stat("rooms_cleared")))],
		["PROFILE_STAT_PERFECT", str(int(_profile.get_stat("rooms_perfect")))],
		["PROFILE_STAT_DAMAGE", str(roundi(float(_profile.get_stat("damage_taken"))))],
		["PROFILE_STAT_TIME", format_time(float(_profile.get_stat("time_played")))],
		["PROFILE_STAT_RETRIES", str(int(_profile.get_stat("retries")))],
		["PROFILE_STAT_TRAPS", str(int(_profile.get_stat("traps_hit")))],
	]
	for row_variant in rows:
		var row := row_variant as Array
		grid.add_child(_stat_label(tr(str(row[0])), muted_color()))
		grid.add_child(_stat_label(str(row[1]), text_color()))
	return grid


func _stat_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _build_badges() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = BADGE_COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 10)
	for entry in _profile.badges_view():
		var tile := BadgeTile.create(entry, text_color(), muted_color())
		_badge_tiles.append(tile)
		grid.add_child(tile)
	return grid


func _build_log() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	var entries := _profile.recent_xp(LOG_LINES)
	if entries.is_empty():
		column.add_child(_stat_label(tr("PROFILE_EMPTY_LOG"), muted_color()))
		return column
	for entry in entries:
		var context: Dictionary = entry.get("ctx", {})
		var reason := str(entry.get("reason", ""))
		var text := ProgressionBreakdown.reason_text(reason)
		if reason == "badge":
			text = "%s: %s" % [text, AchievementCatalog.display_name(AchievementCatalog.find(str(context.get("badge", ""))))]
		elif reason == "rank":
			text = "%s %s" % [text, str(context.get("rank", ""))]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var amount := _stat_label("+%s XP" % ScoreBreakdown.thousands(int(entry.get("xp", 0))), text_color())
		amount.size_flags_horizontal = Control.SIZE_FILL
		amount.custom_minimum_size = Vector2(70.0, 0.0)
		line.add_child(amount)
		line.add_child(_stat_label(text, text_color()))
		var when := _stat_label(BadgeTile.format_date(int(entry.get("t", 0))), muted_color())
		when.size_flags_horizontal = Control.SIZE_SHRINK_END
		when.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(when)
		column.add_child(line)
	return column


static func format_time(seconds: float) -> String:
	var total := maxi(roundi(seconds), 0)
	if total >= 3600:
		return "%d:%02d:%02d" % [total / 3600, (total % 3600) / 60, total % 60]
	return "%02d:%02d" % [total / 60, total % 60]
