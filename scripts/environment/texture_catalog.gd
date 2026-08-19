class_name TextureCatalog
extends RefCounted

## Materiales de las superficies del nivel.
##
## Lee level_designs/texture-catalog.json, el mismo archivo que la herramienta
## usa para ofrecer la lista, asi que la relacion identificador -> archivo vive
## en un solo lugar. Un identificador vacio o desconocido cae en el material
## procedural de siempre, y por eso un nivel sin texturas sigue construyendose
## igual que antes.

const CATALOG_PATH := "res://level_designs/texture-catalog.json"
## Metros que ocupa un mosaico cuando la entrada no declara el suyo.
const DEFAULT_TILE_METERS := 2.0

static var _entries: Dictionary = {}
static var _materials: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(CATALOG_PATH):
		push_warning("Texture catalog not found: %s" % CATALOG_PATH)
		return
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_warning("Texture catalog could not be opened: %s" % CATALOG_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Texture catalog must contain a JSON object.")
		return
	for entry_variant in (parsed as Dictionary).get("textures", []):
		var entry := entry_variant as Dictionary
		var id := str(entry.get("id", ""))
		if id.is_empty():
			continue
		_entries[id] = entry


## Solo para las pruebas: obliga a releer el catalogo del disco.
static func reload() -> void:
	_loaded = false
	_entries.clear()
	_materials.clear()
	_ensure_loaded()


static func get_ids() -> PackedStringArray:
	_ensure_loaded()
	var ids := PackedStringArray()
	for id in _entries:
		ids.append(str(id))
	return ids


static func has_texture(id: String) -> bool:
	_ensure_loaded()
	return _entries.has(id)


## Material con la textura pedida, o null si el identificador no esta en el
## catalogo. Los materiales se comparten entre las salas que usan la misma
## textura, asi que el nivel no crea uno por pared.
static func get_material(id: String) -> StandardMaterial3D:
	_ensure_loaded()
	if id.is_empty() or not _entries.has(id):
		return null
	if _materials.has(id):
		return _materials[id] as StandardMaterial3D
	var entry := _entries[id] as Dictionary
	var path := str(entry.get("path", ""))
	if not ResourceLoader.exists(path):
		push_warning("Texture %s points to a missing file: %s" % [id, path])
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		push_warning("Texture %s could not be loaded: %s" % [id, path])
		return null
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.roughness = 0.95
	var tile := maxf(float(entry.get("tile", DEFAULT_TILE_METERS)), 0.05)
	# Las cajas CSG traen UV de 0 a 1 por cara, asi que mapear por UV estiraria
	# la textura segun la proporcion de cada pared. Con proyeccion triplanar en
	# espacio de mundo el mosaico mide lo mismo en todas las superficies y ademas
	# calza entre cajas vecinas.
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3(1.0 / tile, 1.0 / tile, 1.0 / tile)
	_materials[id] = material
	return material


## Material de una superficie de la sala, con el respaldo procedural que ya
## usaba el nivel cuando no hay textura configurada.
static func resolve(level: Dictionary, room: Dictionary, slot: String, fallback: Material) -> Material:
	var id := LevelDefinitionLoader.get_room_texture(level, room, slot)
	var material := get_material(id)
	return material if material != null else fallback
