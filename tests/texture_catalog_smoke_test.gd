extends SceneTree

## El catalogo de texturas tiene que resolver cada identificador a un material
## utilizable, y el nivel comparador tiene que construirse con esos materiales
## en lugar de los colores planos.

const COMPARATOR_PATH := "res://level_designs/levels/nivel-texturas.json"


func _initialize() -> void:
	create_timer(20.0, true, false, true).timeout.connect(func() -> void: _fail("Texture catalog smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	if not _check_catalog():
		return
	if not _check_comparator():
		return
	print("Texture catalog smoke test passed.")
	quit()


func _check_catalog() -> bool:
	TextureCatalog.reload()
	var ids := TextureCatalog.get_ids()
	if ids.is_empty():
		_fail("The texture catalog should list at least one texture.")
		return false
	for id in ids:
		var material := TextureCatalog.get_material(id)
		if material == null:
			_fail("Texture %s should resolve to a material." % id)
			return false
		if material.albedo_texture == null:
			_fail("Texture %s should carry its image." % id)
			return false
		# Las cajas CSG traen UV de 0 a 1 por cara: sin triplanar el mosaico se
		# estira segun la proporcion de cada pared.
		if not material.uv1_triplanar or not material.uv1_world_triplanar:
			_fail("Texture %s should tile with world triplanar projection." % id)
			return false
		if material.uv1_scale.x <= 0.0:
			_fail("Texture %s should declare a usable tile size." % id)
			return false
	# Pedir dos veces la misma textura devuelve el mismo material.
	if TextureCatalog.get_material(ids[0]) != TextureCatalog.get_material(ids[0]):
		_fail("Materials should be shared between the surfaces that use them.")
		return false
	if TextureCatalog.get_material("no/existe") != null:
		_fail("An unknown texture should resolve to null so the level can fall back.")
		return false
	if TextureCatalog.get_material("") != null:
		_fail("An empty texture id should resolve to null.")
		return false
	return true


## El nivel comparador existe para mirar los packs uno al lado del otro: cada
## sala tiene que quedar con las texturas que declara.
func _check_comparator() -> bool:
	var level := LevelDefinitionLoader.load_level(COMPARATOR_PATH)
	if level.is_empty():
		_fail("The texture comparator level should load.")
		return false
	var packs := {}
	for room_variant in level.rooms:
		var room := room_variant as Dictionary
		var wall_id := LevelDefinitionLoader.get_room_texture(level, room, "walls")
		if wall_id.is_empty():
			_fail("Room %s of the comparator should declare its wall texture." % str(room.name))
			return false
		if not TextureCatalog.has_texture(wall_id):
			_fail("Room %s points to a texture outside the catalog: %s" % [str(room.name), wall_id])
			return false
		for slot in ["walls", "floor", "ceiling"]:
			var id := LevelDefinitionLoader.get_room_texture(level, room, slot)
			var fallback := StandardMaterial3D.new()
			if TextureCatalog.resolve(level, room, slot, fallback) == fallback:
				_fail("Room %s should texture its %s instead of using the flat colour." % [str(room.name), slot])
				return false
		packs[wall_id.get_slice("/", 0)] = true
	if packs.size() < 3:
		_fail("The comparator should show three different packs, found %d." % packs.size())
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
