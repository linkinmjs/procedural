extends SceneTree

## Prueba los dos niveles de agrupacion de objetivos.
##
## El de afuera son las oleadas de la sala: un grupo de bloques aparece, y el
## siguiente no llega hasta que se limpia el anterior. El de adentro son las
## capas de cada bloque, que ya existian.
##
## Tambien cubre la migracion del formato: un nivel escrito en v8 tiene que
## seguir cargando, entendido como una sala de una sola oleada.

const ENCOUNTER_SCRIPT := preload("res://scripts/levels/configured_room_encounter_3d.gd")


func _initialize() -> void:
	create_timer(30.0, true, false, true).timeout.connect(func() -> void: _fail("Room waves smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	if not _check_migration():
		return
	if not _check_layer_types():
		return
	if not await _check_sequential_waves():
		return
	if not await _check_empty_waves_are_skipped():
		return
	if not await _check_crash_blocks_only_its_wall():
		return
	if not await _check_crash_does_not_trap_the_player():
		return
	print("Room waves smoke test passed.")
	quit()


## Un nivel v8 se lee como v9: sus bloques eran una sola oleada, y lo que ahi se
## llamaba `waves` adentro del bloque son las capas. Los archivos del repo ya
## estan en v9, asi que la migracion se prueba contra uno escrito a proposito:
## es la que abre los que alguien tenga guardados afuera.
func _check_migration() -> bool:
	var path := "user://_test_legacy_v8.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(_legacy_level()))
	file.close()
	var level := LevelDefinitionLoader.load_level(path)
	DirAccess.remove_absolute(path)
	if level.is_empty():
		_fail("A v8 level should still load after the format change.")
		return false
	if int(level.schemaVersion) != LevelDefinitionLoader.SUPPORTED_SCHEMA_VERSION:
		_fail("Loading should migrate the level to the supported schema version.")
		return false
	var room: Dictionary = level.rooms[0]
	if room.has("blocks"):
		_fail("A migrated room should not keep its old blocks object.")
		return false
	var waves := LevelDefinitionLoader.get_room_waves(room)
	if waves.size() != 1:
		_fail("The single block group of v8 should become exactly one wave.")
		return false
	var blocks := LevelDefinitionLoader.get_wave_blocks(waves[0])
	if not blocks.has("front"):
		_fail("The migrated wave should keep the block that was enabled.")
		return false
	var layers := LevelDefinitionLoader.get_block_layers(blocks["front"])
	if layers.size() != 2 or layers[0].size() != 4 or layers[1].size() != 3:
		_fail("What v8 called the block waves should become its layers.")
		return false

	# Y los del repo, que ya estan en v9, cargan sin pasar por la migracion.
	var current := LevelDefinitionLoader.load_level("res://level_designs/levels/nivel-1.json")
	if current.is_empty() or int(current.schemaVersion) != LevelDefinitionLoader.SUPPORTED_SCHEMA_VERSION:
		_fail("The campaign level should load on the current schema.")
		return false
	return true


## Nivel v8 minimo: una sala con un bloque frontal de dos oleadas, que es como
## se escribia antes lo que ahora son capas.
func _legacy_level() -> Dictionary:
	return {
		"schemaVersion": 8,
		"id": "legacy-level",
		"name": "Legacy",
		"timeLimitSeconds": 90,
		"gridSize": 1,
		"startingAmmo": {"magazine": 17, "reserve": 51},
		"sky": "clear-day",
		"defaults": {
			"wallHeight": 6, "maxBlockHeight": 6, "hasCeiling": true, "corridorWidth": 3.5,
			"textures": {"walls": "", "floor": "", "ceiling": "", "door": "", "block": ""},
		},
		"rooms": [{
			"id": "legacy-room", "name": "Sala", "type": "small", "role": "start",
			"position": {"x": 0, "z": 0}, "size": {"width": 14, "depth": 14},
			"entry": {"wall": "south", "offset": 0}, "facing": 0,
			"wallHeight": null, "hasCeiling": null,
			"ammoReward": {"enabled": false, "amount": 30, "color": "#f4bc59"},
			"textures": {"walls": "", "floor": "", "ceiling": "", "door": "", "block": ""},
			"blocks": {
				"left": {"enabled": false, "movement": "static", "movementSpeed": 0.65, "color": "#2ed5c5", "waves": []},
				"front": {"enabled": true, "movement": "static", "movementSpeed": 0.65, "color": "#2ed5c5",
					"waves": [{"windows": {"normal": 4}}, {"windows": {"normal": 3}}]},
				"right": {"enabled": false, "movement": "static", "movementSpeed": 0.65, "color": "#2ed5c5", "waves": []},
			},
		}],
		"connections": [],
	}


## Una capa devuelve la familia que va en cada lugar, no un total: es lo que
## permite que una misma capa mezcle ventanas distintas.
func _check_layer_types() -> bool:
	var block := {
		"enabled": true,
		"layers": [
			{"windows": {"normal": 2, "popup": 1}},
			{"windows": {"firewall": 3}},
		],
	}
	var layers := LevelDefinitionLoader.get_block_layers(block)
	if layers.size() != 2:
		_fail("The block should expose one entry per layer.")
		return false
	if layers[0].size() != 3 or layers[1].size() != 3:
		_fail("Each layer should expand to one entry per window.")
		return false
	var first := Array(layers[0])
	if first.count("normal") != 2 or first.count("popup") != 1:
		_fail("A layer should keep how many windows of each family it declares.")
		return false
	# Las familias sin escena propia se juegan como normal, pero el nivel las
	# sigue declarando: el dia que exista su escena no hay que tocar el archivo.
	if WindowCatalog.is_implemented("task-manager"):
		_fail("A family without its own scene should not claim to be implemented.")
		return false
	if not (WindowCatalog.VARIANTS[WindowCatalog.NORMAL_TYPE] as Array).has(WindowCatalog.scene_for("task-manager")):
		_fail("A family without its own scene should fall back to a normal window.")
		return false
	return true


## Tres oleadas, una por slot: al entrar aparece solo la primera, y cada una
## descubre la siguiente al limpiarse.
func _check_sequential_waves() -> bool:
	var encounter := _build_encounter([
		_wave({"front": 2}),
		_wave({"left": 3}),
		_wave({"right": 1}),
	])
	root.add_child(encounter)
	encounter.activate()
	await _wait_frames(2)

	for expected in [["front", 2], ["left", 3], ["right", 1]]:
		var blocks := _blocks_of(encounter)
		if blocks.size() != 1:
			_fail("Wave %s should deploy exactly one block, got %d." % [expected[0], blocks.size()])
			encounter.queue_free()
			return false
		if not str(blocks[0].block_label).ends_with(str(expected[0])):
			_fail("The wave should deploy its %s block." % expected[0])
			encounter.queue_free()
			return false
		if blocks[0].layers.size() != 1 or blocks[0].layers[0].size() != int(expected[1]):
			_fail("The %s block should carry the layer declared for it." % expected[0])
			encounter.queue_free()
			return false
		if encounter.cleared:
			_fail("The room should not be cleared while it still has waves left.")
			encounter.queue_free()
			return false
		# Cerrar el bloque de esta oleada es lo que trae la siguiente.
		blocks[0]._close()
		await _wait_frames(3)

	if not encounter.cleared:
		_fail("Clearing the last wave should clear the room.")
		encounter.queue_free()
		return false
	encounter.queue_free()
	return true


## Una oleada sin bloques habilitados no puede dejar la sala esperando un cierre
## que nunca llega: se saltea.
func _check_empty_waves_are_skipped() -> bool:
	var encounter := _build_encounter([_wave({}), _wave({"front": 1}), _wave({})])
	root.add_child(encounter)
	encounter.activate()
	await _wait_frames(2)
	var blocks := _blocks_of(encounter)
	if blocks.size() != 1:
		_fail("The empty first wave should be skipped.")
		encounter.queue_free()
		return false
	blocks[0]._close()
	await _wait_frames(3)
	if not encounter.cleared:
		_fail("A trailing empty wave should clear the room instead of stalling it.")
		encounter.queue_free()
		return false
	encounter.queue_free()
	return true


## Un bloque colgado deja su pared fuera de juego, pero solo la suya. Lo que la
## oleada siguiente ponia en esa pared no aparece —la pantalla de error la
## ocupa—; lo que ponia en las otras, si.
func _check_crash_blocks_only_its_wall() -> bool:
	var encounter := _build_encounter([
		{"blocks": {
			"left": _blank_block(),
			"front": _block(["infected-download"]),
			"right": _blank_block(),
		}},
		# La segunda oleada vuelve a la misma pared y ademas trae otra: la
		# primera no tiene que llegar, la segunda si.
		{"blocks": {
			"left": _block(["normal", "normal"]),
			"front": _block(["normal"]),
			"right": _blank_block(),
		}},
	])
	root.add_child(encounter)
	encounter.activate()
	await _wait_frames(3)
	var blocks := _blocks_of(encounter)
	if blocks.size() != 1:
		_fail("The first wave should deploy its infected block.")
		encounter.queue_free()
		return false
	var infected: DownloadWindow = null
	for target in blocks[0].spawn_volume.active_targets:
		if target is DownloadWindow:
			infected = target
	if infected == null:
		_fail("The infected family should reach the block.")
		encounter.queue_free()
		return false
	infected.download_seconds = 0.2
	await _wait_seconds(0.6)
	await _wait_frames(5)

	var live := _blocks_of(encounter)
	var crashed_front := 0
	var fresh_left := 0
	var fresh_front := 0
	for block in live:
		var label := str(block.block_label)
		if block._crashed:
			crashed_front += 1
		elif label.ends_with("left"):
			fresh_left += 1
		elif label.ends_with("front"):
			fresh_front += 1
	if crashed_front != 1:
		_fail("The crashed block should stay in the room.")
		encounter.queue_free()
		return false
	if fresh_front != 0:
		_fail("The next wave should not put another block on the crashed wall.")
		encounter.queue_free()
		return false
	if fresh_left != 1:
		_fail("The other walls should keep working, got %d." % fresh_left)
		encounter.queue_free()
		return false
	if encounter.cleared:
		_fail("The room should still be running: its other wall has a live block.")
		encounter.queue_free()
		return false

	# Y limpiando esa otra pared la sala termina, con la pantalla de error en pie.
	for block in live:
		if not block._crashed:
			block._close()
	await _wait_frames(4)
	if not encounter.cleared:
		_fail("Clearing the last live block should clear the room.")
		encounter.queue_free()
		return false
	encounter.queue_free()
	return true


## Si todas las oleadas que quedaban usaban la pared que se colgo, la sala no
## tiene nada mas que traer: tiene que abrirse igual. Sin esto se quedaba
## esperando el cierre de bloques que nunca iban a aparecer y el jugador quedaba
## encerrado con la pantalla de error.
func _check_crash_does_not_trap_the_player() -> bool:
	var encounter := _build_encounter([
		{"blocks": {"left": _blank_block(), "front": _block(["infected-download"]), "right": _blank_block()}},
		{"blocks": {"left": _blank_block(), "front": _block(["normal", "normal"]), "right": _blank_block()}},
	])
	root.add_child(encounter)
	encounter.activate()
	await _wait_frames(3)
	var blocks := _blocks_of(encounter)
	var infected: DownloadWindow = null
	for target in blocks[0].spawn_volume.active_targets:
		if target is DownloadWindow:
			infected = target
	if infected == null:
		_fail("The infected family should reach the block.")
		encounter.queue_free()
		return false
	infected.download_seconds = 0.2
	await _wait_seconds(0.6)
	await _wait_frames(5)
	var live := _blocks_of(encounter)
	if live.size() != 1 or not live[0]._crashed:
		_fail("Only the crashed block should remain, got %d." % live.size())
		encounter.queue_free()
		return false
	if not encounter.cleared:
		_fail("With nothing left to deploy, the room should open instead of trapping the player.")
		encounter.queue_free()
		return false
	encounter.queue_free()
	return true


func _blank_block() -> Dictionary:
	return {
		"enabled": false, "movement": "static", "movementSpeed": 0.65,
		"color": "#2ed5c5", "layers": [],
	}


func _block(families: Array) -> Dictionary:
	var windows: Dictionary = {}
	for family in families:
		windows[family] = int(windows.get(family, 0)) + 1
	return {
		"enabled": true, "movement": "static", "movementSpeed": 0.65,
		"color": "#2ed5c5", "layers": [{"windows": windows}],
	}


func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


## Oleada con los tres slots declarados; solo los nombrados quedan habilitados,
## que es como los escribe la herramienta.
func _wave(targets_by_slot: Dictionary) -> Dictionary:
	var blocks: Dictionary = {}
	for slot in ["left", "front", "right"]:
		var count := int(targets_by_slot.get(slot, 0))
		blocks[slot] = {
			"enabled": count > 0,
			"movement": "static",
			"movementSpeed": 0.65,
			"color": "#2ed5c5",
			"layers": [{"windows": {"normal": count}}] if count > 0 else [],
		}
	return {"blocks": blocks}


func _build_encounter(waves: Array) -> ConfiguredRoomEncounter3D:
	var encounter := ENCOUNTER_SCRIPT.new() as ConfiguredRoomEncounter3D
	encounter.configure({
		"id": "test-room",
		"name": "Sala de prueba",
		"size": {"width": 16.0, "depth": 16.0},
		"entry": {"wall": "south"},
		"waves": waves,
	})
	return encounter


func _blocks_of(encounter: ConfiguredRoomEncounter3D) -> Array[TargetBlock3D]:
	var blocks: Array[TargetBlock3D] = []
	for child in encounter.get_children():
		var block := child as TargetBlock3D
		if block != null and not block.is_queued_for_deletion():
			blocks.append(block)
	return blocks


func _wait_frames(count: int) -> void:
	for _frame in count:
		await physics_frame
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
