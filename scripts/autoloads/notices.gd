extends CanvasLayer

## Avisos del perfil: globos de logro desbloqueado y de subida de nivel.
##
## Vive por encima de los menus para que un logro se lea aunque haya una
## ventana abierta, y sobrevive al cambio de escena: lo que se gana al cerrar
## un nivel puede mostrarse ya en el escritorio. Los avisos salen de a uno, en
## cola, para que tres logros seguidos no se pisen.
##
## Solo avisa lo que pasa en vivo. Lo que el perfil paga al cerrar la partida
## llega marcado como `quiet` y ya se cuenta en la pantalla de resultados.

const LAYER := 130
## Separacion del globo al borde: en el escritorio, sobre la barra de tareas;
## en partida, sobre el margen inferior, entre los vitales y el log.
const DESKTOP_MARGIN := Vector2(8.0, Taskbar.HEIGHT + 6.0)
const GAME_MARGIN := Vector2(0.0, 28.0)

## Segundos que cada globo queda a la vista. Sale de ProgressionSettings; los
## tests lo acortan.
var notice_seconds := 4.0

var _queue: Array[Dictionary] = []
var _current: NoticeBalloon
## El globo se coloca con contenedores y no con anclas: un MarginContainer
## a pantalla completa cuyo margen inferior es la distancia al borde, y una
## fila que lo apoya abajo, a la derecha o al centro segun la piel. Deslizar
## el globo es animar ese margen.
var _anchor: MarginContainer
var _row: HBoxContainer
var _slide_tween: Tween


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_anchor = MarginContainer.new()
	_anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_anchor)
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor.add_child(_row)
	var profile := get_node_or_null("/root/PlayerProfile") as GameProfile
	if profile == null:
		return
	notice_seconds = profile.settings.notice_seconds
	profile.badge_unlocked.connect(_on_badge_unlocked)
	profile.level_up.connect(_on_level_up)


func show_badge(badge: Dictionary) -> void:
	show_text(
		tr("BADGE_TITLE"),
		tr("BADGE_BODY").format({"name": AchievementCatalog.display_name(badge), "xp": int(badge.get("xp", 0))}),
		str(badge.get("icon", "")),
		"badge_unlocked"
	)


func show_level_up(level: int, level_name: String) -> void:
	show_text(tr("LEVELUP_TITLE"), tr("LEVELUP_BODY").format({"name": level_name, "level": level}), AchievementCatalog.ICON_STAR, "level_up")


## `sound` es el evento de Sfx que suena al aparecer; sin stream no suena y no
## rompe, como cualquier evento del catalogo.
func show_text(title: String, body: String, icon_name := "", sound := "") -> void:
	_queue.append({"title": title, "body": body, "icon": icon_name, "sound": sound})
	if _current == null:
		_show_next()


func is_showing() -> bool:
	return _current != null


func pending_count() -> int:
	return _queue.size()


func current_balloon() -> NoticeBalloon:
	return _current


func _on_badge_unlocked(badge: Dictionary, quiet: bool) -> void:
	if not quiet:
		show_badge(badge)


func _on_level_up(level: int, level_name: String, quiet: bool) -> void:
	if not quiet:
		show_level_up(level, level_name)


func _show_next() -> void:
	if _queue.is_empty():
		return
	var entry: Dictionary = _queue.pop_front()
	var icon := BadgeTile.icon_for(str(entry.icon)) if not str(entry.icon).is_empty() else null
	var on_desktop := _is_desktop()
	var balloon := NoticeBalloon.create(str(entry.title), str(entry.body), icon, on_desktop)
	_current = balloon
	_place(balloon, on_desktop)
	balloon.dismissed.connect(_on_dismissed)
	balloon.play_in()
	if not str(entry.sound).is_empty():
		Sfx.play(str(entry.sound))
	# El reloj ignora la pausa y la camara lenta: un globo no se queda colgado
	# porque el nivel termino en slow motion.
	get_tree().create_timer(notice_seconds, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(balloon):
			balloon.play_out()
	)


## En el escritorio, abajo a la derecha sobre la barra, como un globo de la
## bandeja; en partida, abajo y al centro. Entra deslizandose desde un poco
## mas abajo: se anima el margen inferior, que es lo que el contenedor respeta.
func _place(balloon: NoticeBalloon, on_desktop: bool) -> void:
	var margin := DESKTOP_MARGIN if on_desktop else GAME_MARGIN
	_row.alignment = BoxContainer.ALIGNMENT_END if on_desktop else BoxContainer.ALIGNMENT_CENTER
	_anchor.add_theme_constant_override("margin_left", int(margin.x))
	_anchor.add_theme_constant_override("margin_right", int(margin.x))
	balloon.size_flags_vertical = Control.SIZE_SHRINK_END
	_row.add_child(balloon)
	if _slide_tween != null:
		_slide_tween.kill()
	_set_bottom_margin(margin.y - HudStyle.SLIDE_DISTANCE)
	_slide_tween = create_tween()
	_slide_tween.tween_method(_set_bottom_margin, margin.y - HudStyle.SLIDE_DISTANCE, margin.y, HudStyle.DUR_SLIDE_IN) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_bottom_margin(value: float) -> void:
	_anchor.add_theme_constant_override("margin_bottom", int(value))


func _on_dismissed() -> void:
	_current = null
	_show_next()


## El escritorio se reconoce por su grupo y no por ser la escena actual: en las
## pruebas visuales el menu principal cuelga de otro nodo y sigue siendo el
## escritorio.
func _is_desktop() -> bool:
	return get_tree().get_first_node_in_group(MainMenu.GROUP) != null
