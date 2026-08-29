class_name FailureScreen
extends CanvasLayer

## Pantalla de derrota. Cuando la ronda cae (sin vida, sin tiempo o sin balas)
## el juego no se celebra en camara lenta como una victoria: la imagen se
## apaga como un monitor —una linea blanca que se cierra— y sobre el fondo
## oscuro queda el motivo, para que se entienda que paso antes de que lleguen
## los resultados. Cuelga del nivel y se va con el.
##
## Va debajo de LoadingVeil (63) y de MenuStack (128): los resultados se abren
## encima y el velo de la recarga la tapa al reintentar.

const GROUP := "failure_screen"
const LAYER := 62
const VEIL_COLOR := HudStyle.VEIL
const VEIL_ALPHA := 0.9
const FADE_SECONDS := 0.45
const LINE_SECONDS := 0.35
const LINE_THICKNESS := 3.0
const TEXT_FADE_SECONDS := 0.3
const TITLE_FONT_SIZE := 30
const HINT_FONT_SIZE := 16

## Motivo con el que se mostro (`health_depleted`, `time_expired`,
## `ammo_depleted`).
var reason := ""

var _veil: ColorRect
var _line: ColorRect
var _box: VBoxContainer
var _title: Label
var _hint: Label
var _tween: Tween


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	_build()


## Apaga la pantalla con el motivo a la vista. El titulo es el mismo que
## despues encabeza los resultados; la pista de abajo dice, en una linea, que
## fue lo que fallo.
func show_reason(new_reason: String) -> void:
	reason = new_reason
	_title.text = "%s // %s" % [tr("FAIL_TITLE"), ScoreBreakdown.reason_text(reason)]
	var hint_key := "FAIL_HINT_%s" % reason.to_upper()
	var hint := tr(hint_key)
	_hint.text = "" if hint == hint_key else hint
	Sfx.play("round_failed")
	_animate()


func _animate() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var viewport_size := get_viewport().get_visible_rect().size
	_line.size = Vector2(viewport_size.x, LINE_THICKNESS)
	_line.position = Vector2(0.0, (viewport_size.y - LINE_THICKNESS) * 0.5)
	_line.pivot_offset = _line.size * 0.5
	_line.scale = Vector2.ONE
	_line.modulate.a = 1.0
	_box.modulate.a = 0.0
	# Corre en tiempo real y aunque el arbol se pause: el reloj del nivel ya
	# no manda sobre esta pantalla.
	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	_tween.tween_property(_veil, "color:a", VEIL_ALPHA, FADE_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_line, "scale:x", 0.0, LINE_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_line, "modulate:a", 0.0, 0.1).set_delay(LINE_SECONDS)
	_tween.tween_property(_box, "modulate:a", 1.0, TEXT_FADE_SECONDS).set_delay(FADE_SECONDS * 0.6)


func _build() -> void:
	_veil = ColorRect.new()
	_veil.color = Color(VEIL_COLOR, 0.0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)

	_line = ColorRect.new()
	_line.name = "Line"
	_line.color = Color.WHITE
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.modulate.a = 0.0
	add_child(_line)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.modulate.a = 0.0
	center.add_child(_box)

	_title = Label.new()
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", HudStyle.DANGER)
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_box.add_child(_title)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", HudStyle.TEXT_DIM)
	_hint.add_theme_font_size_override("font_size", HINT_FONT_SIZE)
	_box.add_child(_hint)
