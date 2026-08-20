class_name RoundController
extends Node

signal health_changed(current_health: float, max_health: float)
signal time_changed(time_remaining: float)
signal accuracy_changed(hits: int, attacks: int, accuracy_percent: float)
signal ammo_changed(magazine_ammo: int, reserve_ammo: int)
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
signal room_entered(room_id: String, room_label: String)
signal room_cleared(room_id: String, room_label: String)

@export_range(1.0, 1000.0, 1.0) var max_health := 100.0
@export_range(1.0, 3600.0, 1.0) var round_duration := 90.0
@export var auto_start := true

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


func report_ammo_changed(ammo: Array) -> void:
	if ammo.size() < 2:
		push_warning("RoundController received an invalid ammo update.")
		return
	magazine_ammo = maxi(int(ammo[0]), 0)
	reserve_ammo = maxi(int(ammo[1]), 0)
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
	match reason:
		"health_depleted":
			add_log(tr("LOG_ROUND_FAILED"), "danger")
		"exit_reached":
			add_log(tr("LOG_ROUND_COMPLETE_EXIT"), "system")
		_:
			add_log(tr("LOG_ROUND_COMPLETE_TIME"), "system")
	round_ended.emit(reason)


func _disconnect_weapon_manager() -> void:
	if _weapon_manager.attack_fired.is_connected(report_attack_fired):
		_weapon_manager.attack_fired.disconnect(report_attack_fired)
	if _weapon_manager.target_hit.is_connected(report_attack_hit):
		_weapon_manager.target_hit.disconnect(report_attack_hit)
	if _weapon_manager.has_signal("update_ammo") and _weapon_manager.update_ammo.is_connected(report_ammo_changed):
		_weapon_manager.update_ammo.disconnect(report_ammo_changed)
