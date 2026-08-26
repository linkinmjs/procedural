class_name WindowDesignCatalog
extends RefCounted

## Diseños de ventana del Window Workshop.
##
## Lee level_designs/window-designs.json, el mismo archivo que la herramienta
## escribe, asi que la relacion slug -> diseño vive en un solo lugar. Un diseño
## agrupa variantes esteticas sobre una familia existente: la familia decide
## como se juega; la variante, como se ve. Los niveles lo nombran como
## `custom:<slug>` en las capas de sus bloques, y un slug desconocido degrada a
## una ventana normal, igual que las familias sin escena propia.

const CATALOG_PATH := "res://level_designs/window-designs.json"

static var _designs: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(CATALOG_PATH):
		push_warning("Window design catalog not found: %s" % CATALOG_PATH)
		return
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_warning("Window design catalog could not be opened: %s" % CATALOG_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Window design catalog must contain a JSON object.")
		return
	for entry_variant in (parsed as Dictionary).get("designs", []):
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var slug := str(entry.get("slug", ""))
		if slug.is_empty() or not entry.get("variants", null) is Array:
			continue
		_designs[slug] = entry


## Solo para las pruebas: obliga a releer el catalogo del disco.
static func reload() -> void:
	_loaded = false
	_designs.clear()
	_ensure_loaded()


static func has_design(slug: String) -> bool:
	_ensure_loaded()
	return _designs.has(slug)


static func get_design(slug: String) -> Dictionary:
	_ensure_loaded()
	return _designs.get(slug, {}) as Dictionary


static func get_slugs() -> PackedStringArray:
	_ensure_loaded()
	var slugs := PackedStringArray()
	for slug in _designs:
		slugs.append(str(slug))
	return slugs


static func design_name(slug: String) -> String:
	var design := get_design(slug)
	var name := str(design.get("name", ""))
	return name if not name.is_empty() else slug


## Variante al azar del diseño, usando el generador que le pasen para que un
## nivel con semilla fija se vea siempre igual. Misma doctrina que
## WindowCatalog.scene_for.
static func variant_for(design: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var variants: Array = []
	for variant_candidate in design.get("variants", []):
		if variant_candidate is Dictionary:
			variants.append(variant_candidate)
	if variants.is_empty():
		return {}
	if variants.size() == 1:
		return variants[0]
	var index := rng.randi_range(0, variants.size() - 1) if rng != null else randi() % variants.size()
	return variants[index]
