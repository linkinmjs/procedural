class_name EntryAwareTargetEncounter3D
extends Area3D

const SPAWN_VOLUME_SCENE := preload("res://scenes/targets/target_spawn_volume_3d.tscn")

enum ActivationMode {
	OPPOSITE_ENTRY_WALL,
	ALL_VOLUMES,
	CORRIDOR_LATERALS,
}

@export var activation_mode := ActivationMode.OPPOSITE_ENTRY_WALL
@export var one_shot := true
@export var spawn_volumes: Array[TargetSpawnVolume3D] = []
@export_range(1, 32, 1) var targets_per_volume := 4
@export_range(0, 32, 1) var penalty_targets_per_volume := 1
@export var minimum_separation := Vector2(1.0, 1.0)
@export var debug_bounds_visible := true

var _activated := false


func configure_for_room(room_size: Vector3, is_corridor: bool) -> void:
	activation_mode = ActivationMode.CORRIDOR_LATERALS if is_corridor else ActivationMode.OPPOSITE_ENTRY_WALL
	var trigger_shape := $TriggerShape.shape as BoxShape3D
	trigger_shape.size = Vector3(
		maxf(room_size.x - 1.0, 0.5),
		maxf(room_size.y - 1.0, 0.5),
		maxf(room_size.z - 1.0, 0.5)
	)
	var block_height := clampf(room_size.y - 2.0, 2.0, 4.5)
	var vertical_center := -room_size.y * 0.5 + 2.75
	var x_wall_offset := maxf(room_size.x * 0.5 - 0.75, 0.0)
	var z_wall_offset := maxf(room_size.z * 0.5 - 0.75, 0.0)
	_add_spawn_volume("WallPositiveX", Vector3(x_wall_offset, vertical_center, 0.0), Vector3(0.6, block_height, maxf(room_size.z - 2.0, 1.0)))
	_add_spawn_volume("WallNegativeX", Vector3(-x_wall_offset, vertical_center, 0.0), Vector3(0.6, block_height, maxf(room_size.z - 2.0, 1.0)))
	_add_spawn_volume("WallPositiveZ", Vector3(0.0, vertical_center, z_wall_offset), Vector3(maxf(room_size.x - 2.0, 1.0), block_height, 0.6))
	_add_spawn_volume("WallNegativeZ", Vector3(0.0, vertical_center, -z_wall_offset), Vector3(maxf(room_size.x - 2.0, 1.0), block_height, 0.6))


func _add_spawn_volume(volume_name: String, local_position: Vector3, volume_size: Vector3) -> void:
	var volume := SPAWN_VOLUME_SCENE.instantiate() as TargetSpawnVolume3D
	volume.name = volume_name
	volume.position = local_position
	volume.size = volume_size
	volume.target_count = targets_per_volume
	volume.penalty_target_count = mini(penalty_targets_per_volume, targets_per_volume)
	volume.minimum_separation = minimum_separation
	volume.spawn_on_ready = false
	volume.debug_bounds_visible = debug_bounds_visible
	add_child(volume)
	spawn_volumes.append(volume)


func _enter_tree() -> void:
	# Parent _enter_tree runs before child _ready, preventing encounter-owned
	# volumes from spawning before an entry direction is known.
	for volume in spawn_volumes:
		if is_instance_valid(volume):
			volume.spawn_on_ready = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D or (_activated and one_shot):
		return
	activate_from(body.global_position)


func activate_from(entry_global_position: Vector3) -> void:
	var valid_volumes: Array[TargetSpawnVolume3D] = []
	for volume in spawn_volumes:
		if is_instance_valid(volume):
			valid_volumes.append(volume)
	if valid_volumes.is_empty():
		return
	_activated = true
	if activation_mode == ActivationMode.ALL_VOLUMES:
		for volume in valid_volumes:
			volume.spawn_targets()
		return
	var entry_local_position := to_local(entry_global_position)
	if activation_mode == ActivationMode.CORRIDOR_LATERALS:
		_spawn_corridor_laterals(valid_volumes, entry_local_position)
		return
	var opposite_volume: TargetSpawnVolume3D = valid_volumes[0]
	var greatest_distance := -INF
	for volume in valid_volumes:
		var distance: float = volume.position.distance_squared_to(entry_local_position)
		if distance > greatest_distance:
			greatest_distance = distance
			opposite_volume = volume
	opposite_volume.spawn_targets()


func _spawn_corridor_laterals(volumes: Array[TargetSpawnVolume3D], entry_local_position: Vector3) -> void:
	var entry_is_on_x_axis := absf(entry_local_position.x) > absf(entry_local_position.z)
	for volume in volumes:
		var volume_is_on_x_axis := absf(volume.position.x) > absf(volume.position.z)
		if volume_is_on_x_axis != entry_is_on_x_axis:
			volume.spawn_targets()
