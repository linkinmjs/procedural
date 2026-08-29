extends SceneTree

## El preset Web excluye del export las texturas que ningun nivel de la campaña
## usa (tools/generate_export_filters.mjs). Este test recalcula ese conjunto
## desde los JSON y lo compara con export_presets.cfg: si un nivel adopto una
## textura nueva, o el catalogo cambio, hay que volver a correr el generador.

const PRESETS_PATH := "res://export_presets.cfg"
const SEQUENCE_PATH := "res://level_designs/level-sequence.json"
const FIXED_EXCLUDES := ["tests/*", "docs/*"]
const HINT := "run `node tools/generate_export_filters.mjs`"


func _initialize() -> void:
	var used := _used_texture_ids()
	if used.is_empty():
		_fail("The campaign should use at least one catalog texture.")
		return
	var expected := {}
	for pattern in FIXED_EXCLUDES:
		expected[pattern] = true
	for id in TextureCatalog.get_ids():
		if not used.has(id):
			expected[TextureCatalog.get_texture_path(id).trim_prefix("res://")] = true

	var presets := ConfigFile.new()
	if presets.load(PRESETS_PATH) != OK:
		_fail("export_presets.cfg should be readable.")
		return
	var actual := {}
	for pattern in str(presets.get_value("preset.0", "exclude_filter", "")).split(",", false):
		actual[pattern.strip_edges()] = true
	for pattern in expected:
		if not actual.has(pattern):
			_fail("The Web preset should exclude %s; %s." % [pattern, HINT])
			return
	for pattern in actual:
		if not expected.has(pattern):
			_fail("The Web preset excludes %s, which the campaign uses; %s." % [pattern, HINT])
			return
	print("Export filter parity smoke test passed (%d textures used, %d excluded)." % [used.size(), expected.size() - FIXED_EXCLUDES.size()])
	quit()


## Los ids que declara la campaña, en los cinco slots del nivel y de cada sala.
func _used_texture_ids() -> Dictionary:
	var used := {}
	var sequence: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEQUENCE_PATH))
	if not sequence is Dictionary:
		return used
	for entry_variant in (sequence as Dictionary).get("levels", []):
		var level := LevelDefinitionLoader.load_level(str((entry_variant as Dictionary).get("path", "")))
		if level.is_empty():
			continue
		for room_variant in level.rooms:
			for slot in LevelDefinitionLoader.VALID_TEXTURE_SLOTS:
				var id := LevelDefinitionLoader.get_room_texture(level, room_variant as Dictionary, slot)
				if not id.is_empty():
					used[id] = true
	return used


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
