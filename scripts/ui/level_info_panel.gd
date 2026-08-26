class_name LevelInfoPanel
extends CyberPanel

## Identidad del nivel, arriba a la izquierda: nombre y estado de la ronda.
##
## Es informacion de contexto, no de combate: se muestra al entrar y despues se
## corre sola de la pantalla (fade) para dejar la esquina limpia. Reaparece un
## momento cuando pasa algo que cambia el contexto (entrar a una sala,
## limpiarla, terminar la ronda) y se vuelve a ir.
##
## Se bindea al RoundController por grupo, igual que el resto del HUD: el que
## instancia la escena no tiene que cablear nada.

@onready var status_label: Label = %StatusLabel

var _controller: RoundController
var _entrance_tween: Tween
var _fade_tween: Tween


func _ready() -> void:
	super()
	call_deferred("_bind_available_controller")


func bind(controller: RoundController) -> void:
	if controller == null or controller == _controller:
		return
	_controller = controller
	controller.round_armed.connect(_on_round_armed)
	controller.round_started.connect(_on_round_started)
	controller.round_ended.connect(_on_round_ended)
	controller.room_entered.connect(_on_room_event)
	controller.room_cleared.connect(_on_room_event)
	status_label.text = "HUD_ROUND_ACTIVE" if controller.is_running else "HUD_ROUND_STANDBY"
	_play_entrance()


func _bind_available_controller() -> void:
	var controllers := get_tree().get_nodes_in_group("round_controller")
	if not controllers.is_empty():
		bind(controllers[0] as RoundController)


## Primer panel de la cascada de entrada del HUD (delay cero): entra desde la
## izquierda y se queda hasta que la ronda arranca.
func _play_entrance() -> void:
	await get_tree().process_frame
	# Un reinicio del nivel puede liberar el panel entre el bind y este frame; la
	# continuacion del await no debe tocar un nodo muerto.
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var base := position
	modulate.a = 0.0
	if _entrance_tween != null:
		_entrance_tween.kill()
	position = base + Vector2(-HudStyle.SLIDE_DISTANCE, 0.0)
	# El slide de posicion vive en su propio tween: un evento de ronda que llegue
	# durante la entrada corta el fade, pero no puede dejar el panel descolocado.
	_entrance_tween = create_tween()
	_entrance_tween.tween_property(self, "position", base, HudStyle.DUR_SLIDE_IN) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, HudStyle.DUR_SLIDE_IN)


func _on_round_armed() -> void:
	status_label.text = "HUD_ROUND_STANDBY"
	_show_for(HudStyle.LEVEL_PANEL_HOLD)


func _on_round_started() -> void:
	status_label.text = "HUD_ROUND_ACTIVE"
	_show_for(HudStyle.LEVEL_PANEL_HOLD)


func _on_round_ended(reason: String) -> void:
	status_label.text = "HUD_ROUND_FAILED" if reason == "health_depleted" else "HUD_ROUND_COMPLETE"
	_show_for(HudStyle.LEVEL_PANEL_PEEK)


func _on_room_event(_room_id: String, _room_label: String) -> void:
	_show_for(HudStyle.LEVEL_PANEL_PEEK)


## Se enciende ya y programa su propia salida. Cada llamada reinicia el reloj.
func _show_for(seconds: float) -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	modulate.a = 1.0
	_fade_tween = create_tween()
	_fade_tween.tween_interval(seconds)
	_fade_tween.tween_property(self, "modulate:a", 0.0, HudStyle.DUR_PANEL_FADE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
