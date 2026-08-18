class_name TargetBall
extends StaticBody3D

signal destroyed(target: TargetBall)
signal left(target: TargetBall)

@export var target_label := "cyan ball"
@export_range(0.0, 120.0, 0.1) var lifetime_seconds := 0.0
@export_range(0.0, 100.0, 1.0) var damage_on_leave := 0.0

var _resolved := false


func _ready() -> void:
	if lifetime_seconds > 0.0:
		get_tree().create_timer(lifetime_seconds, false).timeout.connect(_on_lifetime_expired)


func Hit_Successful(_damage: float, _direction := Vector3.ZERO, _hit_position := Vector3.ZERO) -> void:
	if _resolved:
		return
	_resolved = true
	var round_controller := _get_round_controller()
	if round_controller != null:
		round_controller.report_target_hit(target_label)
	destroyed.emit(self)
	queue_free()


func _on_lifetime_expired() -> void:
	if _resolved:
		return
	_resolved = true
	var round_controller := _get_round_controller()
	if round_controller != null:
		round_controller.report_target_left(target_label, damage_on_leave)
	left.emit(self)
	queue_free()


func _get_round_controller() -> RoundController:
	var controllers := get_tree().get_nodes_in_group("round_controller")
	if controllers.is_empty():
		return null
	return controllers[0] as RoundController
