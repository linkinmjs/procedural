class_name ScoreHUD
extends CanvasLayer

## Lectura del puntaje durante la partida: contador de combo arriba al centro
## y marcador.
##
## Esta version prioriza que se entienda el sistema, no que se celebre: el
## contador dice literalmente pozo x multiplicador para que se lea el trato que
## el jugador esta haciendo. El tratamiento juicy viene despues.
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

@onready var combo_box: Control = %ComboBox
@onready var hits_value: Label = %HitsValue
@onready var multiplier_value: Label = %MultiplierValue
@onready var chain_timer: ProgressBar = %ChainTimer
@onready var pending_value: Label = %PendingValue
@onready var score_value: Label = %ScoreValue

var _controller: ScoreController
var _bank_hold_remaining := 0.0


func _ready() -> void:
	set_process(false)
	combo_box.visible = false
	# LabelSettings pisa a modulate y a los overrides de theme, asi que el color
	# del contador se escribe ahi. Se duplica para no tocar el recurso compartido.
	hits_value.label_settings = hits_value.label_settings.duplicate()
	multiplier_value.label_settings = multiplier_value.label_settings.duplicate()
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
	_on_score_changed(controller.total_score)
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


func _on_score_changed(total: int) -> void:
	score_value.text = ScoreBreakdown.thousands(total)


func _on_chain_changed(hits: int, multiplier: float, pot: int) -> void:
	var is_live := hits > 0 or pot > 0
	# El reseteo que sigue a un cobro no puede tapar el cobro que se esta
	# mostrando; una cadena nueva si, y lo corta.
	if not is_live and _bank_hold_remaining > 0.0:
		return
	_bank_hold_remaining = 0.0
	set_process(false)
	combo_box.visible = is_live
	if not is_live:
		return
	hits_value.text = tr("HUD_HITS").format({"hits": hits})
	multiplier_value.text = "x%.1f" % multiplier
	pending_value.text = "%s x %.1f = %s" % [ScoreBreakdown.thousands(pot), multiplier, ScoreBreakdown.thousands(roundi(pot * multiplier))]
	_paint_counter(_color_for_step(hits))


func _on_chain_timer_changed(remaining: float, window: float) -> void:
	if _bank_hold_remaining > 0.0:
		return
	chain_timer.max_value = maxf(window, 0.01)
	chain_timer.value = remaining


## El cobro se queda unos segundos resuelto en pantalla: los hits que quedaron,
## el multiplicador con el que se pago y la cuenta ya cerrada.
func _on_chain_banked(hits: int, pot: int, multiplier: float, awarded: int, _reason: String) -> void:
	if pot == 0 and hits == 0:
		combo_box.visible = false
		return
	combo_box.visible = true
	hits_value.text = tr("HUD_HITS").format({"hits": hits})
	multiplier_value.text = "x%.1f" % multiplier
	pending_value.text = "%s x %.1f = %s" % [ScoreBreakdown.thousands(pot), multiplier, ScoreBreakdown.thousands(awarded)]
	_paint_counter(BANK_COLOR)
	chain_timer.value = 0.0
	_bank_hold_remaining = BANK_HOLD_SECONDS
	set_process(true)


## Al cerrar el nivel el HUD se corre del medio y deja el cobro de la ultima
## cadena a la vista. El desglose llega despues, en la pantalla de resultados.
func _on_level_scored(_summary: Dictionary) -> void:
	if _bank_hold_remaining <= 0.0:
		combo_box.visible = false


func _paint_counter(color: Color) -> void:
	hits_value.label_settings.font_color = color
	multiplier_value.label_settings.font_color = color


func _color_for_step(hits: int) -> Color:
	if _controller == null or _controller.settings == null:
		return STEP_COLORS[0]
	var step := _controller.settings.step_for_hits(hits)
	return STEP_COLORS[clampi(step, 0, STEP_COLORS.size() - 1)]

