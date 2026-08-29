class_name RoundController
extends Node

signal health_changed(current_health: float, max_health: float)
signal time_changed(time_remaining: float)
signal accuracy_changed(hits: int, attacks: int, accuracy_percent: float)
signal ammo_changed(magazine_ammo: int, reserve_ammo: int)
## Balas que entraron a la reserva al tomar una recompensa.
signal ammo_collected(amount: int)
signal log_added(message: String, event_kind: String)
signal round_armed
signal round_started
signal round_ended(reason: String)
## Un disparo ya resuelto: true si toco un objetivo, false si se perdio.
signal shot_resolved(hit: bool)
## Un objetivo resuelto. kind es "window" o "ball"; zone_id viaja vacio en las
## pelotas, que no tienen zonas.
signal target_resolved(kind: String, label: String, zone_id: String, closed: bool)
signal damage_taken(amount: float)
## No quedan balas, ni disparos en el aire, ni burbujas que las traigan, y
## todavia hay ventanas que cerrar: la ronda cae en `seconds` si nada cambia.
signal ammo_depleted_warning(seconds: float)
## Aparecieron balas (o una burbuja) durante la gracia: el aviso se retira.
signal ammo_depleted_cleared
signal room_entered(room_id: String, room_label: String)
signal room_cleared(room_id: String, room_label: String)

@export_range(1.0, 1000.0, 1.0) var max_health := 100.0
@export_range(1.0, 3600.0, 1.0) var round_duration := 90.0
@export var auto_start := true

## Gracia entre quedarse sin balas y perder la ronda: lo justo para leer el
## aviso y para que una burbuja en viaje llegue a destino.
const AMMO_GRACE_SECONDS := 2.5
## Grupo de las burbujas de municion (AmmoBubble.GROUP); se consulta por
## nombre para no depender de la clase.
const AMMO_BUBBLE_GROUP := "ammo_bubble"

var current_health := 100.0
var time_remaining := 90.0
var hits := 0
var attacks := 0
var magazine_ammo := 0
var reserve_ammo := 0
var is_running := false

var _weapon_manager: Node
## Disparos hechos y todavia sin resolver. El impacto de una bala hitscan llega
## en el mismo cuadro que el disparo, asi que lo que sigue sin resolverse al
## final del cuadro es un fallo.
var _unresolved_shots := 0
var _shot_resolution_queued := false
## Quien sabe si todavia hay algo que disparar (lo fija el nivel). Sin
## consulta se asume que si.
var remaining_targets_query: Callable
## Si queda alguna burbuja con balas que el jugador pueda ir a buscar. La pone
## el nivel, que sabe que salas estan selladas; sin consulta cuentan todas las
## burbujas del arbol.
var ammo_available_query: Callable
## El arma ya informo su municion alguna vez: sin ese dato, cero balas no
## significa nada (un controlador suelto arranca en cero).
var _ammo_known := false
var _ammo_empty_seconds := 0.0
var _ammo_warning_active := false


func _ready() -> void:
	add_to_group("round_controller")
	if auto_start:
		start_round()


func _process(delta: float) -> void:
	if not is_running:
		return
	time_remaining = maxf(time_remaining - delta, 0.0)
	time_changed.emit(time_remaining)
	if is_zero_approx(time_remaining):
		_finish_round("time_expired")
		return
	_tick_ammo_depletion(delta)


## Deja la ronda lista pero con el cronometro detenido. El nivel la arranca
## recien cuando el jugador sale de la primera habitacion.
func arm_round() -> void:
	_reset_counters()
	is_running = false
	_emit_round_state()
	round_armed.emit()


func start_round() -> void:
	if is_running:
		return
	_reset_counters()
	is_running = true
	_emit_round_state()
	round_started.emit()
	add_log(tr("LOG_ROUND_STARTED"), "system")


## Cierra la ronda porque el jugador llego a la ultima habitacion.
func complete_round() -> void:
	_finish_round("exit_reached")


func _reset_counters() -> void:
	current_health = max_health
	time_remaining = round_duration
	hits = 0
	attacks = 0
	_unresolved_shots = 0
	_ammo_empty_seconds = 0.0
	_ammo_warning_active = false


func _emit_round_state() -> void:
	health_changed.emit(current_health, max_health)
	time_changed.emit(time_remaining)
	accuracy_changed.emit(hits, attacks, get_accuracy_percent())
	ammo_changed.emit(magazine_ammo, reserve_ammo)


func register_player(player: Node) -> void:
	if player == null:
		return
	var manager := player.get_node_or_null("Camera/LeanPivot/MainCamera/Weapons_Manager")
	if manager == null:
		push_warning("RoundController could not find the player's Weapons_Manager.")
		return
	if is_instance_valid(_weapon_manager):
		_disconnect_weapon_manager()
	_weapon_manager = manager
	if manager.has_signal("attack_fired"):
		manager.attack_fired.connect(report_attack_fired)
	if manager.has_signal("target_hit"):
		manager.target_hit.connect(report_attack_hit)
	if manager.has_signal("update_ammo"):
		manager.update_ammo.connect(report_ammo_changed)
	var current_slot: Variant = manager.get("current_weapon_slot")
	if current_slot != null:
		report_ammo_changed([current_slot.current_ammo, current_slot.reserve_ammo])


## Una burbuja de municion se tomo: `amount` es lo que entro en la reserva.
func report_ammo_collected(amount: int) -> void:
	if amount > 0:
		ammo_collected.emit(amount)


func report_ammo_changed(ammo: Array) -> void:
	if ammo.size() < 2:
		push_warning("RoundController received an invalid ammo update.")
		return
	magazine_ammo = maxi(int(ammo[0]), 0)
	reserve_ammo = maxi(int(ammo[1]), 0)
	_ammo_known = true
	ammo_changed.emit(magazine_ammo, reserve_ammo)


func report_attack_fired() -> void:
	if not is_running:
		return
	attacks += 1
	_unresolved_shots += 1
	if not _shot_resolution_queued:
		_shot_resolution_queued = true
		_resolve_pending_shots.call_deferred()
	_emit_accuracy()


func report_attack_hit() -> void:
	if not is_running:
		return
	hits += 1
	_unresolved_shots = maxi(_unresolved_shots - 1, 0)
	shot_resolved.emit(true)
	_emit_accuracy()


## Lo que quedo sin impacto al cerrar el cuadro fallo.
func _resolve_pending_shots() -> void:
	_shot_resolution_queued = false
	while _unresolved_shots > 0:
		_unresolved_shots -= 1
		shot_resolved.emit(false)


func report_target_hit(target_label: String) -> void:
	add_log(tr("LOG_HIT").format({"target": target_label.to_upper()}), "hit")


## Una zona de ventana resuelta. closes indica si el impacto la cerro.
func report_zone_hit(window_label: String, zone_id: String, closes: bool) -> void:
	report_target_hit("%s // %s" % [window_label, zone_id])
	target_resolved.emit("window", window_label, zone_id, closes)


func report_ball_destroyed(target_label: String) -> void:
	report_target_hit(target_label)
	target_resolved.emit("ball", target_label, "", true)


## El jugador entro a una sala con objetivos: es lo que abre una cadena.
func report_room_entered(room_id: String, room_label: String) -> void:
	room_entered.emit(room_id, room_label)


func report_room_cleared(room_id: String, room_label: String) -> void:
	room_cleared.emit(room_id, room_label)


func report_target_left(target_label: String, damage: float) -> void:
	add_log(tr("LOG_TARGET_LEFT").format({
		"target": target_label.to_upper(),
		"damage": roundi(damage),
	}), "miss")
	if damage > 0.0:
		apply_damage(damage)


func report_block_crossed(block_label: String, damage: float) -> void:
	add_log(tr("LOG_CROSSED").format({
		"block": block_label.to_upper(),
		"damage": roundi(damage),
	}), "danger")
	if damage > 0.0:
		apply_damage(damage)


## Sin balas en el arma, sin disparos por resolver, sin burbujas que las
## traigan y con ventanas por cerrar, la ronda esta perdida: se avisa, se
## espera la gracia y se corta. Cualquier bala que aparezca en el medio
## cancela el aviso.
func _tick_ammo_depletion(delta: float) -> void:
	if not is_out_of_ammo():
		_clear_ammo_depletion()
		return
	if not _ammo_warning_active:
		_ammo_warning_active = true
		_ammo_empty_seconds = 0.0
		add_log(tr("LOG_AMMO_OUT"), "danger")
		ammo_depleted_warning.emit(AMMO_GRACE_SECONDS)
	_ammo_empty_seconds += delta
	if _ammo_empty_seconds >= AMMO_GRACE_SECONDS:
		_finish_round("ammo_depleted")


## Si el jugador no tiene con que seguir: ni balas, ni disparos en el aire,
## ni burbujas con balas, y todavia queda algo que disparar.
func is_out_of_ammo() -> bool:
	if not _ammo_known or magazine_ammo + reserve_ammo > 0 or _unresolved_shots > 0:
		return false
	if remaining_targets_query.is_valid() and not bool(remaining_targets_query.call()):
		return false
	if ammo_available_query.is_valid():
		return not bool(ammo_available_query.call())
	for bubble in get_tree().get_nodes_in_group(AMMO_BUBBLE_GROUP):
		if is_instance_valid(bubble) and int(bubble.get("amount")) > 0:
			return false
	return true


func _clear_ammo_depletion() -> void:
	_ammo_empty_seconds = 0.0
	if _ammo_warning_active:
		_ammo_warning_active = false
		ammo_depleted_cleared.emit()


func apply_damage(amount: float) -> void:
	if not is_running or amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	damage_taken.emit(amount)
	if is_zero_approx(current_health):
		_finish_round("health_depleted")


func add_log(message: String, event_kind := "info") -> void:
	log_added.emit(message, event_kind)


func get_accuracy_percent() -> float:
	if attacks <= 0:
		return 0.0
	return float(hits) / float(attacks) * 100.0


func _emit_accuracy() -> void:
	accuracy_changed.emit(hits, attacks, get_accuracy_percent())


func _finish_round(reason: String) -> void:
	if not is_running:
		return
	is_running = false
	_clear_ammo_depletion()
	match reason:
		"health_depleted":
			add_log(tr("LOG_ROUND_FAILED"), "danger")
		"ammo_depleted":
			add_log(tr("LOG_ROUND_FAILED_AMMO"), "danger")
		"exit_reached":
			add_log(tr("LOG_ROUND_COMPLETE_EXIT"), "system")
		_:
			add_log(tr("LOG_ROUND_FAILED_TIME"), "danger")
	round_ended.emit(reason)


func _disconnect_weapon_manager() -> void:
	if _weapon_manager.attack_fired.is_connected(report_attack_fired):
		_weapon_manager.attack_fired.disconnect(report_attack_fired)
	if _weapon_manager.target_hit.is_connected(report_attack_hit):
		_weapon_manager.target_hit.disconnect(report_attack_hit)
	if _weapon_manager.has_signal("update_ammo") and _weapon_manager.update_ammo.is_connected(report_ammo_changed):
		_weapon_manager.update_ammo.disconnect(report_ammo_changed)
