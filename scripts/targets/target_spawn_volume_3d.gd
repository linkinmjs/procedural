@tool
class_name TargetSpawnVolume3D
extends Node3D

signal targets_spawned(targets: Array[TargetBall])
signal all_targets_destroyed

@export var target_scene: PackedScene = preload("res://scenes/targets/target_ball.tscn")
@export var penalty_target_scene: PackedScene = preload("res://scenes/targets/blue_penalty_ball.tscn")
@export_range(1, 64, 1) var target_count := 8
@export_range(0, 64, 1) var penalty_target_count := 0
@export var size := Vector3(10.0, 4.0, 0.6):
	set(value):
		size = value.max(Vector3(0.1, 0.1, 0.1))
		_update_debug_bounds()
@export_range(0.0, 10.0, 0.05) var minimum_spacing := 1.0
@export var edge_padding := Vector3(0.4, 0.4, 0.0)
@export var random_seed := 0
@export var spawn_on_ready := true
@export var debug_bounds_visible := true:
	set(value):
		debug_bounds_visible = value
		_update_debug_bounds()

@onready var debug_bounds: MeshInstance3D = $DebugBounds
@onready var targets_container: Node3D = $Targets

var active_targets: Array[TargetBall] = []
var _debug_active := false


func _ready() -> void:
	_update_debug_bounds()
	if not Engine.is_editor_hint() and spawn_on_ready:
		spawn_targets()


func spawn_targets() -> void:
	if Engine.is_editor_hint() or target_scene == null:
		return
	_debug_active = true
	_update_debug_bounds()
	clear_targets()
	var rng := RandomNumberGenerator.new()
	if random_seed == 0:
		rng.randomize()
	else:
		rng.seed = random_seed
	var positions := _build_spawn_positions(rng)
	var penalty_indices := _pick_penalty_indices(positions.size(), rng)
	for index in positions.size():
		var scene_to_spawn := penalty_target_scene if penalty_indices.has(index) else target_scene
		var target := scene_to_spawn.instantiate() as TargetBall
		if target == null:
			push_error("TargetSpawnVolume3D requires a scene with TargetBall as its root.")
			continue
		targets_container.add_child(target)
		target.position = positions[index]
		target.destroyed.connect(_on_target_destroyed)
		target.left.connect(_on_target_left)
		active_targets.append(target)
	targets_spawned.emit(active_targets.duplicate())


func clear_targets() -> void:
	for target in active_targets:
		if is_instance_valid(target):
			target.queue_free()
	active_targets.clear()


func _build_spawn_positions(rng: RandomNumberGenerator) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var half_size := Vector3(
		maxf(size.x * 0.5 - edge_padding.x, 0.0),
		maxf(size.y * 0.5 - edge_padding.y, 0.0),
		maxf(size.z * 0.5 - edge_padding.z, 0.0)
	)
	if is_zero_approx(half_size.x) or is_zero_approx(half_size.y) or is_zero_approx(half_size.z):
		push_warning("TargetSpawnVolume3D edge_padding leaves no usable spawn space.")
		return positions
	var attempts_remaining := target_count * 30
	while positions.size() < target_count and attempts_remaining > 0:
		attempts_remaining -= 1
		var candidate := Vector3(
			rng.randf_range(-half_size.x, half_size.x),
			rng.randf_range(-half_size.y, half_size.y),
			rng.randf_range(-half_size.z, half_size.z)
		)
		if positions.all(func(existing: Vector3) -> bool: return existing.distance_to(candidate) >= minimum_spacing):
			positions.append(candidate)
	if positions.size() < target_count:
		push_warning("TargetSpawnVolume3D could only place %d of %d targets. Increase size or reduce minimum_spacing." % [positions.size(), target_count])
	return positions


func _on_target_destroyed(target: TargetBall) -> void:
	_resolve_target(target)


func _on_target_left(target: TargetBall) -> void:
	_resolve_target(target)


func _resolve_target(target: TargetBall) -> void:
	active_targets.erase(target)
	if active_targets.is_empty():
		all_targets_destroyed.emit()


func _pick_penalty_indices(available_count: int, rng: RandomNumberGenerator) -> Array[int]:
	var candidates: Array[int] = []
	for index in available_count:
		candidates.append(index)
	for index in range(candidates.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var previous := candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = previous
	return candidates.slice(0, mini(penalty_target_count, available_count))


func _update_debug_bounds() -> void:
	if not is_node_ready():
		return
	debug_bounds.visible = debug_bounds_visible and (Engine.is_editor_hint() or _debug_active)
	var box := debug_bounds.mesh as BoxMesh
	box.size = size
