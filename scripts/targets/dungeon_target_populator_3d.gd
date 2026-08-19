class_name DungeonTargetPopulator3D
extends Node

const ENCOUNTER_SCENE := preload("res://scenes/targets/entry_aware_target_encounter_3d.tscn")

@export_range(1, 32, 1) var targets_per_wall := 4
@export_range(0, 32, 1) var penalty_targets_per_wall := 1
@export var minimum_separation := Vector2(1.0, 1.0)
@export var debug_bounds_visible := true


func populate(dungeon_generator: DungeonGenerator3D) -> void:
	for room_node in dungeon_generator.find_children("*", "DungeonRoom3D", true, false):
		var room := room_node as DungeonRoom3D
		if room == null or _is_player_start_room(room):
			continue
		var encounter := ENCOUNTER_SCENE.instantiate() as EntryAwareTargetEncounter3D
		encounter.targets_per_volume = targets_per_wall
		encounter.penalty_targets_per_volume = mini(penalty_targets_per_wall, targets_per_wall)
		encounter.minimum_separation = minimum_separation
		encounter.debug_bounds_visible = debug_bounds_visible
		var is_corridor := room.scene_file_path == dungeon_generator.corridor_room_scene.resource_path
		encounter.configure_for_room(Vector3(room.size_in_voxels) * room.voxel_scale, is_corridor)
		room.add_child(encounter)


func _is_player_start_room(room: DungeonRoom3D) -> bool:
	for descendant in room.find_children("*", "", true, false):
		if descendant.is_in_group("player_spawn_point"):
			return true
	return false
