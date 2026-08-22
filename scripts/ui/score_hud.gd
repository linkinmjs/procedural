class_name ScoreHUD
extends CanvasLayer

## Lectura del puntaje durante la partida: contador de combo arriba al centro
## y marcador.
##
## El contador dice literalmente pozo x multiplicador para que se lea el trato
## que el jugador esta haciendo, y ademas lo celebra: punch al subir de
## escalon, sacudida al caer, rotura con el costo a la vista cuando la cadena
## se cierra forzada, y cobro dorado con el numero rodando al limpiar la sala.
##
## El desglose del nivel no vive aca: es la pantalla de resultados, que llega
## unos segundos despues y ademas deja elegir que hacer con el intento. Tenerlo
## en los dos lados contaba dos veces lo mismo.

## Color por escalon de la cadena. El ultimo se repite si hay mas escalones.
const STEP_COLORS: Array[Color] = [
	Color(0.66, 0.76, 0.84),
	Color(0.42, 0.90, 1.00),
	Color(0.36, 1.00, 0.78),
	Color(0.72, 1.00, 0.38),
	Color(1.00, 0.90, 0.30),
	Color(1.00, 0.58, 0.24),
	Color(1.00, 0.30, 0.42),
]
## Segundos que el cobro queda a la vista despues de cerrar la cadena. Sin esta
## pausa el contador desaparece junto con el ultimo objetivo y el jugador nunca
## llega a ver cuanto acumulo, que es justo el momento de pago del sistema.
const BANK_HOLD_SECONDS := 2.5
const BANK_COLOR := Color(1.00, 0.82, 0.28)
## Colores del cierre forzado, por motivo: el danio y la trampa duelen en
## rojo/naranja, el timeout se apaga en gris sin violencia (no fue un golpe).
const LOST_COLORS := {
	"damage": Color(1.0, 0.32, 0.32),
	"trap": Color(1.0, 0.52, 0.2),
	"timeout": Color(0.55, 0.6, 0.65),
	"round_ended": Color(0.55, 0.6, 0.65),
}
## Debajo de esta fraccion del timer, la barra entra en modo urgencia.
const TIMER_DANGER_RATIO := 0.25
## Un acierto con el timer por debajo de esto es una "salvada" y se celebra.
const SAVE_RATIO := 0.15
const TIMER_BASE_COLOR := Color(0.36, 0.92, 1.0)
const TIMER_DANGER_COLOR := Color(1.0, 0.32, 0.28)

@onready var combo_box: Control = %ComboBox
@onready var hits_value: Label = %HitsValue
@onready var multiplier_value: Label = %MultiplierValue
@onready var chain_timer: ProgressBar = %ChainTimer
@onready var pending_value: Label = %PendingValue
@onready var score_value: Label = %ScoreValue

var _controller: ScoreController
var _bank_hold_remaining := 0.0
var _last_step := 0
var _last_hits := 0
var _last_timer_ratio := 1.0
var _tick_slot := -1
var _shown_score := 0.0
var _punch_tween: Tween
var _shake_tween: Tween
var _shake_base_x := 0.0
var _score_tween: Tween
var _pending_tween: Tween
var _color_tween: Tween
var _timer_fill: StyleBoxFlat


func _ready() -> void:
	set_process(false)
	combo_box.visible = false
	# LabelSettings pisa a modulate y a los overrides de theme, asi que el color
	# del contador se escribe ahi. Se duplica para no tocar el recurso compartido.
	hits_value.label_settings = hits_value.label_settings.duplicate()
	multiplier_value.label_settings = multiplier_value.label_settings.duplicate()
	_timer_fill = chain_timer.get("theme_override_styles/fill") as StyleBoxFlat
	_bind_available_controller.call_deferred()


## Solo corre mientras hay un cobro sosteniendose en pantalla; el resto del
## tiempo el contador no tiene nada que contar.
func _process(delta: float) -> void:
	_bank_hold_remaining -= delta
	if _bank_hold_remaining > 0.0:
		return
	set_process(false)
	if _controller == null or (_controller.chain_hits <= 0 and _controller.pot <= 0):
		combo_box.visible = false


func bind(controller: ScoreController) -> void:
	if controller == null or controller == _controller:
		return
	_controller = controller
	controller.score_changed.connect(_on_score_changed)
	controller.chain_changed.connect(_on_chain_changed)
	controller.chain_timer_changed.connect(_on_chain_timer_changed)
	controller.chain_banked.connect(_on_chain_banked)
	controller.level_scored.connect(_on_level_scored)
	_shown_score = float(controller.total_score)
	score_value.text = ScoreBreakdown.thousands(controller.total_score)
	_on_chain_changed(controller.chain_hits, controller.get_multiplier(), controller.pot)


## Solo busca controlador si nadie lo asigno antes: un bind explicito manda
## sobre lo que haya en el grupo.
func _bind_available_controller() -> void:
	if _controller != null:
		return
	for node in get_tree().get_nodes_in_group("score_controller"):
		if is_instance_valid(node):
			bind(node as ScoreController)
			return


## El total nunca salta: rueda hasta el valor nuevo, para que se vea que el
## marcador esta cobrando.
func _on_score_changed(total: int) -> void:
	if _score_tween != null:
		_score_tween.kill()
	_score_tween = create_tween()
	_score_tween.tween_method(_set_shown_score, _shown_score, float(total), 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_shown_score(value: float) -> void:
	_shown_score = value
	score_value.text = ScoreBreakdown.thousands(roundi(value))


func _on_chain_changed(hits: int, multiplier: float, pot: int) -> void:
	var is_live := hits > 0 or pot > 0
	# El reseteo que sigue a un cobro no puede tapar el cobro que se esta
	# mostrando; una cadena nueva si, y lo corta.
	if not is_live and _bank_hold_remaining > 0.0:
		_last_step = 0
		_last_hits = 0
		return
	_bank_hold_remaining = 0.0
	set_process(false)
	combo_box.visible = is_live
	if not is_live:
		_last_step = 0
		_last_hits = 0
		return
	hits_value.text = tr("HUD_HITS").format({"hits": hits})
	multiplier_value.text = "x%.1f" % multiplier
	pending_value.text = "%s x %.1f = %s" % [ScoreBreakdown.thousands(pot), multiplier, ScoreBreakdown.thousands(roundi(pot * multiplier))]
	var step := _step_for_hits(hits)
	var color := _color_for_step(hits)
	if step > _last_step:
		_celebrate_step_up(step, color)
	elif step < _last_step:
		_suffer_step_drop()
	else:
		_paint_counter(color)
	if hits > _last_hits and _last_timer_ratio < SAVE_RATIO and _last_hits > 0:
		_celebrate_save()
	_last_step = step
	_last_hits = hits


## Subir de escalon: punch de escala y destello de blanco al color nuevo, con
## el pitch del sonido subiendo escalon a escalon.
func _celebrate_step_up(step: int, color: Color) -> void:
	Sfx.play("combo_step_up", 1.0 + step * 0.12)
	_paint_counter(Color.WHITE)
	if _color_tween != null:
		_color_tween.kill()
	_color_tween = create_tween()
	_color_tween.tween_method(_paint_counter_lerp.bind(Color.WHITE, color), 0.0, 1.0, 0.3)
	_punch(1.28)


## Caer de escalon: sacudida horizontal y destello rojo. Tiene que doler un
## poco, sin castigar la vista.
func _suffer_step_drop() -> void:
	Sfx.play("combo_drop")
	_paint_counter(Color(1.0, 0.4, 0.4))
	if _color_tween != null:
		_color_tween.kill()
	_color_tween = create_tween()
	_color_tween.tween_interval(0.12)
	_color_tween.tween_callback(func() -> void: _paint_counter(_color_for_step(_controller.chain_hits if _controller != null else 0)))
	_shake()


## Acierto con el timer casi agotado: destello blanco. Salvar la racha sobre
## la hora es un micro-momento de gloria y merece leerse distinto.
func _celebrate_save() -> void:
	Sfx.play("chain_saved")
	_punch(1.15)


func _on_chain_timer_changed(remaining: float, window: float) -> void:
	_last_timer_ratio = remaining / maxf(window, 0.01)
	if _bank_hold_remaining > 0.0:
		return
	chain_timer.max_value = maxf(window, 0.01)
	chain_timer.value = remaining
	_update_timer_urgency(remaining)


## La barra avisa que la cadena se muere: funde su color a rojo cerca del
## final, parpadea en el tramo critico y deja un gancho de tic sonoro.
func _update_timer_urgency(remaining: float) -> void:
	if _timer_fill != null:
		var danger := 1.0 - clampf(_last_timer_ratio / 0.5, 0.0, 1.0)
		_timer_fill.bg_color = TIMER_BASE_COLOR.lerp(TIMER_DANGER_COLOR, danger)
	if _last_timer_ratio < TIMER_DANGER_RATIO and remaining > 0.0:
		var pulse := 0.65 + 0.35 * absf(sin(Time.get_ticks_msec() * 0.012))
		chain_timer.modulate = Color(1.0, 1.0, 1.0, pulse)
		var slot := int(remaining * 2.0)
		if slot != _tick_slot:
			_tick_slot = slot
			Sfx.play("chain_tick")
	else:
		chain_timer.modulate = Color.WHITE
		_tick_slot = -1


## El cobro se queda unos segundos resuelto en pantalla: los hits que quedaron,
## el multiplicador con el que se pago y la cuenta ya cerrada. Limpiar la sala
## cobra en dorado con el numero rodando; un cierre forzado muestra ademas
## cuanto costo cobrarse a x1.
func _on_chain_banked(hits: int, pot: int, multiplier: float, awarded: int, reason: String) -> void:
	if pot == 0 and hits == 0:
		combo_box.visible = false
		return
	# Un roll de un cobro anterior todavia corriendo pisaria el texto de este
	# cierre: se corta antes de escribir nada.
	if _pending_tween != null:
		_pending_tween.kill()
	# El fundido de color de un escalon tampoco puede pisar el color del cierre.
	if _color_tween != null:
		_color_tween.kill()
	combo_box.visible = true
	hits_value.text = tr("HUD_HITS").format({"hits": hits})
	multiplier_value.text = "x%.1f" % multiplier
	chain_timer.value = 0.0
	chain_timer.modulate = Color.WHITE
	_bank_hold_remaining = BANK_HOLD_SECONDS
	set_process(true)
	_last_step = 0
	_last_hits = 0
	if reason == ScoreController.REASON_ROOM_CLEARED:
		Sfx.play("bank")
		_paint_counter(BANK_COLOR)
		_punch(1.35)
		_roll_pending(pot, multiplier, awarded)
		return
	# Cierre forzado: se pago a x1. El costo de oportunidad se muestra, porque
	# es el motivador real para cuidar la racha.
	Sfx.play("chain_lost")
	var color: Color = LOST_COLORS.get(reason, LOST_COLORS["timeout"])
	_paint_counter(color)
	var lost := 0
	if _controller != null and _controller.settings != null:
		lost = roundi(pot * _controller.settings.multiplier_for_hits(hits)) - awarded
	pending_value.text = "%s x %.1f = %s" % [ScoreBreakdown.thousands(pot), multiplier, ScoreBreakdown.thousands(awarded)]
	if lost > 0:
		pending_value.text += "  (-%s)" % ScoreBreakdown.thousands(lost)
	if reason == ScoreController.REASON_DAMAGE or reason == ScoreController.REASON_TRAP:
		_shake()


## El numero del cobro rueda de cero al total: ver la cuenta correr es lo que
## hace sentir que el pozo se esta pagando.
func _roll_pending(pot: int, multiplier: float, awarded: int) -> void:
	if _pending_tween != null:
		_pending_tween.kill()
	_pending_tween = create_tween()
	_pending_tween.tween_method(
		func(value: float) -> void:
			pending_value.text = "%s x %.1f = %s" % [ScoreBreakdown.thousands(pot), multiplier, ScoreBreakdown.thousands(roundi(value))],
		0.0, float(awarded), 0.55
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Al cerrar el nivel el HUD se corre del medio y deja el cobro de la ultima
## cadena a la vista. El desglose llega despues, en la pantalla de resultados.
func _on_level_scored(_summary: Dictionary) -> void:
	if _bank_hold_remaining <= 0.0:
		combo_box.visible = false


func _punch(peak: float) -> void:
	if _punch_tween != null:
		_punch_tween.kill()
	combo_box.pivot_offset = combo_box.size * 0.5
	combo_box.scale = Vector2.ONE * peak
	_punch_tween = create_tween()
	_punch_tween.tween_property(combo_box, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shake() -> void:
	# La posicion base sale del layout (anclas): se captura solo cuando no hay
	# una sacudida en curso, para no tomar un offset a mitad de camino.
	if _shake_tween != null and _shake_tween.is_running():
		combo_box.position.x = _shake_base_x
		_shake_tween.kill()
	else:
		_shake_base_x = combo_box.position.x
	_shake_tween = create_tween()
	for offset in [9.0, -7.0, 5.0, -3.0]:
		_shake_tween.tween_property(combo_box, "position:x", _shake_base_x + offset, 0.04)
	_shake_tween.tween_property(combo_box, "position:x", _shake_base_x, 0.04)


func _paint_counter(color: Color) -> void:
	hits_value.label_settings.font_color = color
	multiplier_value.label_settings.font_color = color


func _paint_counter_lerp(weight: float, from: Color, to: Color) -> void:
	_paint_counter(from.lerp(to, weight))


func _step_for_hits(hits: int) -> int:
	if _controller == null or _controller.settings == null:
		return 0
	return _controller.settings.step_for_hits(hits)


func _color_for_step(hits: int) -> Color:
	return STEP_COLORS[clampi(_step_for_hits(hits), 0, STEP_COLORS.size() - 1)]
