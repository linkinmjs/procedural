class_name TargetBlock3D
extends Area3D

signal closed(block: TargetBlock3D)

@export var block_label := "front block"
@export_range(0, 64, 1) var target_count := 4
@export var waves: Array[int] = []
@export var block_color := Color(0.08, 0.78, 1.0, 1.0)
@export var moves_to_opposite_side := false
@export_range(0.05, 5.0, 0.05) var movement_speed := 0.65
@export_range(0.0, 100.0, 0.1) var travel_distance := 10.0
@export_range(0.0, 100.0, 1.0) var crossing_damage := 15.0
@export var movement_direction := Vector3.ZERO
@export var block_size := Vector2(8.0, 4.0)
## Escenas que puede spawnear el bloque. Cada objetivo elige una al azar.
@export var target_scenes: Array[PackedScene] = [
	preload("res://scenes/windows/shutdown_window.tscn"),
	preload("res://scenes/windows/close_window.tscn"),
	preload("res://scenes/windows/download_window.tscn"),
]
## Separacion minima entre objetivos y margen interior del bloque, en metros.
## Los valores por defecto contemplan el tamaño de una ventana.
## Con valores menores al tamaño del objetivo las ventanas se superponen, que es
## el comportamiento buscado. El volumen las escalona en profundidad y cada una
## se recorta contra los bordes del bloque, asi que el solape se ve limpio.
@export var target_separation := Vector2(2.0, 1.0)
@export var target_padding := Vector2(0.2, 0.2)

@onready var block_mesh: MeshInstance3D = $BlockMesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var spawn_volume: TargetSpawnVolume3D = $TargetSpawnVolume3D

var _distance_travelled := 0.0
var _closing := false
var _bodies_inside: Array[Node3D] = []
var _wave_counts: Array[int] = []
var _current_wave_index := 0


func _ready() -> void:
	_update_geometry()
	_update_appearance()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_wave_counts.assign(waves)
	if _wave_counts.is_empty() and target_count > 0:
		_wave_counts.append(target_count)
	if not _wave_counts.is_empty():
		spawn_volume.penalty_target_count = 0
		spawn_volume.spawn_on_ready = false
		spawn_volume.all_targets_destroyed.connect(_on_wave_cleared)
		_spawn_current_wave()
	else:
		spawn_volume.visible = false
		_spawn_close_control()


func _physics_process(delta: float) -> void:
	if not moves_to_opposite_side or _closing or movement_direction.is_zero_approx():
		return
	if _distance_travelled >= travel_distance:
		return
	var step := minf(movement_speed * delta, travel_distance - _distance_travelled)
	position += movement_direction.normalized() * step
	_distance_travelled += step


func _update_geometry() -> void:
	var physical_size := Vector3(block_size.x, block_size.y, 0.28)
	var mesh := block_mesh.mesh as BoxMesh
	mesh.size = physical_size
	var shape := collision_shape.shape as BoxShape3D
	shape.size = physical_size
	spawn_volume.position = Vector3(0.0, 0.0, 0.5)
	spawn_volume.size = Vector3(maxf(block_size.x - 1.0, 0.5), maxf(block_size.y - 1.0, 0.5), 0.02)
	spawn_volume.edge_padding = Vector3(target_padding.x, target_padding.y, 0.0)
	spawn_volume.minimum_separation = target_separation
	spawn_volume.target_scenes = target_scenes


func _update_appearance() -> void:
	var mesh := block_mesh.mesh as BoxMesh
	if mesh != null and mesh.material is StandardMaterial3D:
		var material := mesh.material.duplicate() as StandardMaterial3D
		var panel_color := block_color
		panel_color.a = 0.2
		material.albedo_color = panel_color
		material.emission = block_color.darkened(0.45)
		mesh.material = material
	spawn_volume.target_color = block_color


func _spawn_current_wave() -> void:
	if _closing or _current_wave_index >= _wave_counts.size():
		return
	spawn_volume.target_count = _wave_counts[_current_wave_index]
	spawn_volume.spawn_targets()
	if spawn_volume.active_targets.is_empty():
		push_warning("%s wave %d could not place any targets; skipping it." % [block_label, _current_wave_index + 1])
		call_deferred("_on_wave_cleared")
	var controller := _get_round_controller()
	if controller != null:
		controller.add_log("%s // WAVE %d/%d // %d TARGETS" % [block_label.to_upper(), _current_wave_index + 1, _wave_counts.size(), spawn_volume.target_count], "info")


func _on_wave_cleared() -> void:
	_current_wave_index += 1
	if _current_wave_index >= _wave_counts.size():
		_close()
		return
	call_deferred("_spawn_current_wave")


func _spawn_close_control() -> void:
	var close_target := preload("res://scenes/targets/close_target_ball.tscn").instantiate() as TargetBall
	add_child(close_target)
	close_target.position = Vector3(block_size.x * 0.5 - 0.55, block_size.y * 0.5 - 0.55, 0.5)
	close_target.destroyed.connect(_on_close_control_hit)


func _on_close_control_hit(_target: TargetBall) -> void:
	_close()


func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D or _bodies_inside.has(body):
		return
	_bodies_inside.append(body)
	var controller := _get_round_controller()
	if controller != null:
		controller.report_block_crossed(block_label, crossing_damage)


func _on_body_exited(body: Node3D) -> void:
	_bodies_inside.erase(body)


func _close() -> void:
	if _closing:
		return
	_closing = true
	var controller := _get_round_controller()
	if controller != null:
		controller.add_log("%s CLOSED" % block_label.to_upper(), "system")
	closed.emit(self)
	queue_free()


func _get_round_controller() -> RoundController:
	var controllers := get_tree().get_nodes_in_group("round_controller")
	if controllers.is_empty():
		return null
	return controllers[0] as RoundController
