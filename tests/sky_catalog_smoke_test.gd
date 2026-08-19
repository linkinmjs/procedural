extends SceneTree

## Cada cielo del catalogo tiene que armar su material y colocar la luz, y el
## nivel activo tiene que quedar con el cielo que declara su JSON.


func _initialize() -> void:
	create_timer(15.0, true, false, true).timeout.connect(func() -> void: _fail("Sky catalog smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	if not _check_catalog():
		return
	change_scene_to_file("res://scenes/levels/playable_level.tscn")
	for _frame in 6:
		await process_frame
	var level := current_scene as PlayableLevel
	if level == null or level.level_data.is_empty():
		_fail("The playable level did not load.")
		return
	if not _check_applied(level):
		return
	print("Sky catalog smoke test passed.")
	quit()


func _check_catalog() -> bool:
	var ids := SkyCatalog.get_ids()
	if ids.is_empty():
		_fail("The sky catalog should offer at least one sky.")
		return false
	if not SkyCatalog.has_sky(SkyCatalog.DEFAULT_ID):
		_fail("The default sky should exist in the catalog.")
		return false
	for id in ids:
		var material := SkyCatalog.build_material(id)
		if material == null or material.shader == null:
			_fail("Sky %s should build a shader material." % id)
			return false
		# Sin las cuatro texturas el shader pierde nubes y estrellas.
		for parameter in ["cloud_tex_01", "cloud_tex_02", "night_noise_01", "night_noise_02"]:
			if material.get_shader_parameter(parameter) == null:
				_fail("Sky %s is missing its %s texture." % [id, parameter])
				return false
		var preset := SkyCatalog.resolve(id)
		if not preset.has("light_rotation") or not preset.has("light_energy"):
			_fail("Sky %s should place the directional light." % id)
			return false
	# Un identificador desconocido cae en el cielo por defecto en vez de romper.
	if SkyCatalog.resolve("no-existe") != SkyCatalog.resolve(SkyCatalog.DEFAULT_ID):
		_fail("An unknown sky should fall back to the default one.")
		return false
	return true


func _check_applied(level: PlayableLevel) -> bool:
	var expected_id := LevelDefinitionLoader.get_sky_id(level.level_data)
	var preset := SkyCatalog.resolve(expected_id)
	var environment := level.world_environment.environment
	if environment == null or environment.sky == null:
		_fail("The level environment should hold a sky.")
		return false
	var material := environment.sky.sky_material as ShaderMaterial
	if material == null or material.shader != SkyCatalog.SKY_SHADER:
		_fail("The level should use the sky shader from the catalog.")
		return false
	if material.get_shader_parameter("sky_day") != preset.sky_day:
		_fail("The level should use the colours declared by its sky.")
		return false
	if not level.sun.rotation_degrees.is_equal_approx(preset.light_rotation):
		_fail("The sky should place the directional light of the level.")
		return false
	if not is_equal_approx(level.sun.light_energy, float(preset.light_energy)):
		_fail("The sky should set the energy of the directional light.")
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
