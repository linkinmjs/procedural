class_name RoundController
extends Node

signal health_changed(current_health: float, max_health: float)
signal time_changed(time_remaining: float)
signal accuracy_changed(hits: int, attacks: int, accuracy_percent: float)
signal log_added(message: String, event_kind: String)
signal round_ended(reason: String)

@export_range(1.0, 1000.0, 1.0) var max_health := 100.0
@export_range(1.0, 3600.0, 1.0) var round_duration := 90.0
@export var auto_start := true

var current_health := 100.0
var time_remaining := 90.0
var hits := 0
var attacks := 0
var is_running := false

var _weapon_manager: Node


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


func start_round() -> void:
	current_health = max_health
	time_remaining = round_duration
	hits = 0
	attacks = 0
	is_running = true
	health_changed.emit(current_health, max_health)
	time_changed.emit(time_remaining)
	accuracy_changed.emit(hits, attacks, 0.0)
	add_log("ROUND STARTED", "system")


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


func report_attack_fired() -> void:
	if not is_running:
		return
	attacks += 1
	_emit_accuracy()


func report_attack_hit() -> void:
	if not is_running:
		return
	hits += 1
	_emit_accuracy()


func report_target_hit(target_label: String) -> void:
	add_log("HIT // %s" % target_label.to_upper(), "hit")


func report_target_left(target_label: String, damage: float) -> void:
	add_log("%s LEFT // -%d HP" % [target_label.to_upper(), roundi(damage)], "miss")
	if damage > 0.0:
		apply_damage(damage)


func apply_damage(amount: float) -> void:
	if not is_running or amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
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
	if reason == "health_depleted":
		add_log("ROUND FAILED // HP DEPLETED", "danger")
	else:
		add_log("ROUND COMPLETE // TIME EXPIRED", "system")
	round_ended.emit(reason)


func _disconnect_weapon_manager() -> void:
	if _weapon_manager.attack_fired.is_connected(report_attack_fired):
		_weapon_manager.attack_fired.disconnect(report_attack_fired)
	if _weapon_manager.target_hit.is_connected(report_attack_hit):
		_weapon_manager.target_hit.disconnect(report_attack_hit)
