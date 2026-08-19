extends SceneTree

const SPAWN_VOLUME_SCENE := preload("res://scenes/targets/target_spawn_volume_3d.tscn")


func _initialize() -> void:
	create_timer(3.0).timeout.connect(func() -> void: _fail("Target system smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	var volume := SPAWN_VOLUME_SCENE.instantiate() as TargetSpawnVolume3D
	volume.spawn_on_ready = false
	volume.target_count = 3
	volume.random_seed = 42
	volume.size = Vector3(6.0, 3.0, 0.5)
	volume.minimum_separation = Vector2(0.75, 0.75)
	root.add_child(volume)
	volume.spawn_targets()
	if volume.active_targets.size() != 3:
		_fail("Expected 3 spawned targets, got %d." % volume.active_targets.size())
		return
	var target := volume.active_targets[0]
	target.Hit_Successful(1.0)
	await process_frame
	if volume.active_targets.size() != 2:
		_fail("A hit should destroy exactly one target.")
		return
	if not _test_opposite_entry_selection():
		return
	print("Target system smoke test passed.")
	quit()


func _test_opposite_entry_selection() -> bool:
	var encounter := EntryAwareTargetEncounter3D.new()
	var entry_side := SPAWN_VOLUME_SCENE.instantiate() as TargetSpawnVolume3D
	var opposite_side := SPAWN_VOLUME_SCENE.instantiate() as TargetSpawnVolume3D
	entry_side.target_count = 1
	opposite_side.target_count = 1
	entry_side.position.x = -5.0
	opposite_side.position.x = 5.0
	encounter.add_child(entry_side)
	encounter.add_child(opposite_side)
	encounter.spawn_volumes.assign([entry_side, opposite_side])
	root.add_child(encounter)
	encounter.activate_from(Vector3(-10.0, 0.0, 0.0))
	if not entry_side.active_targets.is_empty() or opposite_side.active_targets.size() != 1:
		_fail("Opposite-entry mode selected the wrong spawn volume.")
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
