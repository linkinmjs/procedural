class_name TargetBall
extends StaticBody3D

signal destroyed(target: TargetBall)
signal left(target: TargetBall)

@export var target_label := "cyan ball"
@export_range(0.0, 120.0, 0.1) var lifetime_seconds := 0.0
@export_range(0.0, 100.0, 1.0) var damage_on_leave := 0.0
@export var display_color := Color(0.08, 0.78, 1.0, 1.0)

var _resolved := false
var use_custom_display_color := false


func _ready() -> void:
	if use_custom_display_color:
		_apply_display_color()
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


func _apply_display_color() -> void:
	var mesh_instance := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	var colored_mesh := mesh_instance.mesh.duplicate() as PrimitiveMesh
	if colored_mesh == null or not colored_mesh.material is StandardMaterial3D:
		return
	var colored_material := colored_mesh.material.duplicate() as StandardMaterial3D
	colored_material.albedo_color = display_color
	colored_material.emission = display_color.darkened(0.58)
	colored_mesh.material = colored_material
	mesh_instance.mesh = colored_mesh
