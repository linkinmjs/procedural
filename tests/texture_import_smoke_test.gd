extends SceneTree

## Las texturas del catalogo se cargan por codigo, asi que el editor nunca las
## detecta en 3D: este test fija el contrato de importacion que el juego
## necesita (VRAM comprimida y con mipmaps) para que ninguna vuelva a quedar
## lossless por accidente. Se arregla con tools/set_texture_import_params.py.


func _initialize() -> void:
	var offenders := PackedStringArray()
	var checked := 0
	for id in TextureCatalog.get_ids():
		var path := TextureCatalog.get_texture_path(id)
		var import_path := path + ".import"
		if not FileAccess.file_exists(import_path):
			offenders.append("%s (sin .import)" % id)
			continue
		var config := ConfigFile.new()
		if config.load(import_path) != OK:
			offenders.append("%s (.import ilegible)" % id)
			continue
		checked += 1
		var mode := int(config.get_value("params", "compress/mode", -1))
		var mipmaps := bool(config.get_value("params", "mipmaps/generate", false))
		if mode != 2 or not mipmaps:
			offenders.append("%s (compress/mode=%d, mipmaps=%s)" % [id, mode, mipmaps])
	if checked == 0:
		_fail("The texture catalog should list textures with .import files.")
		return
	if not offenders.is_empty():
		_fail("%d catalog textures are not imported as VRAM compressed with mipmaps; run `python tools/set_texture_import_params.py` and reimport. First: %s" % [offenders.size(), offenders[0]])
		return
	print("Texture import smoke test passed (%d textures)." % checked)
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
