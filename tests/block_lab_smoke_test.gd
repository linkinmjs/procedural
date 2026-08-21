extends SceneTree

## Prueba el laboratorio de bloques, que es donde se prueban a mano las cosas
## antes de escribirlas en un nivel.
##
## Lo que se verifica es que ofrezca lo mismo que el formato de nivel: capas por
## bloque, familias de ventana y oleadas de sala. Si el laboratorio se queda
## atras deja de servir para lo que existe.

var _lab: Node


func _initialize() -> void:
	create_timer(20.0, true, false, true).timeout.connect(func() -> void: _fail("Block lab smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/sandbox/block_lab.tscn")
	await _wait_frames(2)
	_lab = current_scene
	if _lab == null:
		_fail("Block lab scene did not load.")
		return
	if not _check_presets():
		return
	if not _check_layers_and_families():
		return
	if not await _check_room_waves():
		return
	if not _check_family_catalog():
		return
	if not await _check_infected_download():
		return
	print("Block lab smoke test passed.")
	paused = false
	quit()


## El primer preset es el editable a mano; el resto son ejemplos de lo que el
## formato permite, y tienen que cubrir capas, familias y oleadas.
func _check_presets() -> bool:
	var preset_option := _control("PresetRow/PresetOption") as OptionButton
	if preset_option.item_count < 5:
		_fail("The lab should offer several presets, got %d." % preset_option.item_count)
		return false
	for index in range(1, preset_option.item_count):
		var preset: Dictionary = _lab.LEVEL_PRESETS[index]
		for slot in ["left", "front", "right"]:
			var config: Dictionary = preset[slot]
			for key in ["enabled", "targets", "layers", "family", "wave", "moves"]:
				if not config.has(key):
					_fail("Preset %d is missing %s on its %s block." % [index, key, slot])
					return false
	return true


## Un bloque de tres capas de dos ventanas es seis objetivos repartidos en tres
## tandas, y la familia elegida va en cada lugar.
func _check_layers_and_families() -> bool:
	var layers: Array[PackedStringArray] = _lab.build_layers({
		"target_count": 2, "layer_count": 3, "family": "firewall",
	})
	if layers.size() != 3 or layers[0].size() != 2:
		_fail("Three layers of two should expand to three tandas of two.")
		return false
	if layers[0][0] != "firewall":
		_fail("The chosen family should reach every slot of the layer.")
		return false
	# La mezcla reparte una de cada familia, para verlas convivir.
	var mixed: Array[PackedStringArray] = _lab.build_layers({
		"target_count": 5, "layer_count": 1, "family": "mixed",
	})
	if mixed.size() != 1 or mixed[0].size() != 5:
		_fail("The mixed family should still respect the target count.")
		return false
	var seen := {}
	for family in mixed[0]:
		seen[family] = true
	if seen.size() < 3:
		_fail("The mixed family should spread across several families, got %d." % seen.size())
		return false
	# Un bloque sin objetivos no tiene capas: es el del control de cierre.
	if not _lab.build_layers({"target_count": 0, "layer_count": 2, "family": "normal"}).is_empty():
		_fail("A block without targets should not declare layers.")
		return false
	return true


## El preset de tres oleadas despliega una por vez: al entrar sale la primera, y
## cerrarla trae la siguiente. Es la misma regla que en una sala de la campaña.
func _check_room_waves() -> bool:
	_lab._on_preset_selected(1)
	_lab._apply_configuration()
	_lab._on_entry_trigger_body_entered(_lab.player)
	await _wait_frames(2)

	for expected_slot in ["front", "left", "right"]:
		var blocks := _blocks()
		if blocks.size() != 1:
			_fail("Wave of the %s block should deploy alone, got %d blocks." % [expected_slot, blocks.size()])
			return false
		if blocks[0].block_label != "%s block" % expected_slot:
			_fail("Expected the %s block, got %s." % [expected_slot, blocks[0].block_label])
			return false
		blocks[0]._close()
		await _wait_frames(3)

	if not _blocks().is_empty():
		_fail("Clearing every wave should leave the lab empty.")
		return false
	return true


## El desplegable tiene que ofrecer todo lo que el catalogo sabe construir: si el
## laboratorio no las ofrece, no hay donde probarlas antes de escribir un nivel.
func _check_family_catalog() -> bool:
	for choice in _lab.FAMILY_CHOICES:
		var family := str(choice.id)
		if family == "mixed":
			continue
		if not WindowCatalog.is_implemented(family):
			_fail("The lab offers %s but the catalog cannot build it." % family)
			return false
	for family in WindowCatalog.VARIANTS:
		var offered := false
		for choice in _lab.FAMILY_CHOICES:
			if str(choice.id) == str(family):
				offered = true
		if not offered:
			_fail("The catalog builds %s but the lab does not offer it." % family)
			return false
	# La mezcla no puede colar la infectada: colgaria el bloque al azar y taparia
	# lo que se estuviera probando.
	if _lab.MIXED_FAMILIES.has("infected-download"):
		_fail("The mixed family should leave the infected download out.")
		return false
	return true


## Una descarga infectada que llega al final cuelga el bloque del laboratorio
## igual que el de un nivel: cancela lo que faltaba y deja la pantalla encendida.
func _check_infected_download() -> bool:
	_lab._configured_blocks = {
		"left": _block_config(false),
		"front": _block_config(true, 1, 2, "infected-download"),
		"right": _block_config(false),
	}
	_lab._current_wave = 0
	_lab._pending_blocks.clear()
	_lab._clear_blocks()
	_lab._spawn_configured_blocks()
	await _wait_frames(4)
	var blocks := _blocks()
	if blocks.size() != 1:
		_fail("The infected configuration should deploy its block.")
		return false
	var block := blocks[0]
	var infected: DownloadWindow = null
	for target in block.spawn_volume.active_targets:
		if target is DownloadWindow:
			infected = target
	if infected == null:
		_fail("The infected family should spawn its download in the lab.")
		return false
	infected.download_seconds = 0.2
	await _wait_seconds(0.6)
	await _wait_frames(3)
	if not is_instance_valid(block) or block.is_queued_for_deletion():
		_fail("A crashed block should stay in the room instead of vanishing.")
		return false
	if not block.spawn_volume.active_targets.is_empty():
		_fail("Crashing should cancel the layers the block had left.")
		return false
	# Un bloque colgado no se libera solo: se queda en la sala a proposito. La
	# prueba lo limpia para no dejar el arbol a medio desarmar al salir.
	_lab._clear_blocks()
	await _wait_frames(2)
	return true


func _block_config(enabled: bool, targets := 0, layers := 1, family := "normal") -> Dictionary:
	return {
		"enabled": enabled, "target_count": targets, "layer_count": layers,
		"wave": 1, "family": family, "moves": false,
	}


func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _blocks() -> Array[TargetBlock3D]:
	var blocks: Array[TargetBlock3D] = []
	for child in _lab.get_node("Blocks").get_children():
		var block := child as TargetBlock3D
		if block != null and not block.is_queued_for_deletion():
			blocks.append(block)
	return blocks


func _control(path: String) -> Node:
	return _lab.get_node("ConfigInterface/ConfigPanel/Margin/VBox/%s" % path)


func _wait_frames(count: int) -> void:
	for _frame in count:
		await physics_frame
		await process_frame


func _fail(message: String) -> void:
	paused = false
	push_error(message)
	quit(1)
