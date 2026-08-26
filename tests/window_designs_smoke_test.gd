extends SceneTree

## Prueba los diseños de ventana del Window Workshop.
##
## Un diseño agrupa variantes esteticas sobre una familia existente y los
## niveles lo nombran como `custom:<slug>`. Lo que se verifica es el contrato:
## el catalogo resuelve el slug a escena mas variante, la ventana aplica la
## variante al nacer sin perder el comportamiento de su familia, y un diseño
## borrado degrada a una ventana normal en vez de romper el nivel.

const SEED_SLUG := "estafa-bancaria"
const SEED_TITLES := ["Alerta de seguridad", "Banco Central", "Verificación pendiente"]
const SHUTDOWN := preload("res://scenes/windows/shutdown_window.tscn")
const DOWNLOAD := preload("res://scenes/windows/download_window.tscn")
const BLOCK := preload("res://scenes/targets/target_block_3d.tscn")


func _initialize() -> void:
	create_timer(30.0, true, false, true).timeout.connect(func() -> void: _fail("Window designs smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	if not _check_catalog():
		return
	if not _check_spawn_plan():
		return
	if not await _check_variant_applies():
		return
	if not await _check_variant_size_clamps():
		return
	if not await _check_family_behaviour_survives():
		return
	if not await _check_skin_reskins_chrome():
		return
	if not await _check_block_spawns_design():
		return
	print("Window designs smoke test passed.")
	quit()


## El catalogo lee el archivo que escribe la herramienta y conoce el seed.
func _check_catalog() -> bool:
	if not WindowDesignCatalog.has_design(SEED_SLUG):
		_fail("The seed design %s should be in the catalog." % SEED_SLUG)
		return false
	if not WindowDesignCatalog.get_slugs().has(SEED_SLUG):
		_fail("get_slugs should list the seed design.")
		return false
	if WindowDesignCatalog.design_name(SEED_SLUG).is_empty():
		_fail("The seed design should have a display name.")
		return false
	var design := WindowDesignCatalog.get_design(SEED_SLUG)
	if not design.get("variants", []) is Array or (design.get("variants", []) as Array).is_empty():
		_fail("The seed design should bring at least one variant.")
		return false
	return true


## El plan de spawn resuelve cada tipo a escena mas configuracion: los custom
## traen su variante, las familias de fabrica van vacias y un slug borrado cae
## en una ventana normal.
func _check_spawn_plan() -> bool:
	var plan := WindowCatalog.spawn_plan_for(PackedStringArray(["custom:%s" % SEED_SLUG, "normal"]))
	if plan.size() != 2:
		_fail("The plan should bring one entry per window.")
		return false
	var custom := plan[0]
	var family := str(WindowDesignCatalog.get_design(SEED_SLUG).get("family", ""))
	if not (WindowCatalog.VARIANTS.get(family, []) as Array).has(custom.scene):
		_fail("A custom window should use a scene of its family.")
		return false
	if (custom.config as Dictionary).is_empty() or not (custom.config as Dictionary).has("base"):
		_fail("A custom window should carry its variant config.")
		return false
	if not (plan[1].config as Dictionary).is_empty():
		_fail("A factory family should carry no config.")
		return false

	# Con varias variantes, el azar tiene que alternarlas: con semilla fija el
	# resultado es reproducible, asi que la variedad se puede exigir.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var seen := {}
	for _index in 30:
		var entry := WindowCatalog.spawn_plan_for(PackedStringArray(["custom:%s" % SEED_SLUG]), rng)[0]
		seen[str((entry.config as Dictionary).get("title", ""))] = true
	if seen.size() < 2:
		_fail("Thirty spawns of a three-variant design should show more than one variant.")
		return false

	var missing := WindowCatalog.spawn_plan_for(PackedStringArray(["custom:no-existe"]))[0]
	if not (WindowCatalog.VARIANTS[WindowCatalog.NORMAL_TYPE] as Array).has(missing.scene):
		_fail("A deleted design should degrade to a normal window.")
		return false
	if not (missing.config as Dictionary).is_empty():
		_fail("A deleted design should not carry stale config.")
		return false
	return true


## La ventana aplica titulo, mensaje y tamaño al nacer, y el quad y las zonas
## se miden con el tamaño final.
func _check_variant_applies() -> bool:
	var window := SHUTDOWN.instantiate() as WindowPanel3D
	window.variant_config = {
		"title": "Alerta de seguridad",
		"message": "Su cuenta fue bloqueada.",
		"size": {"width": 340, "height": 160},
	}
	root.add_child(window)
	await _wait_frames(3)
	var title := window.content.find_child("Title", true, false) as Label
	var message := window.content.find_child("Message", true, false) as Label
	if title == null or title.text != "Alerta de seguridad":
		_fail("The variant title should replace the scene title.")
		window.free()
		return false
	if message == null or message.text != "Su cuenta fue bloqueada.":
		_fail("The variant message should replace the scene message.")
		window.free()
		return false
	if window.sub_viewport.size != Vector2i(340, 160):
		_fail("The variant size should resize the SubViewport, got %s." % str(window.sub_viewport.size))
		window.free()
		return false
	var expected := Vector2(340.0, 160.0) / window.pixels_per_meter
	if not window.get_window_size().is_equal_approx(expected):
		_fail("get_window_size should reflect the variant size.")
		window.free()
		return false
	if window.get_hit_bodies().is_empty():
		_fail("A resized window should still build its hit zones.")
		window.free()
		return false
	window.free()

	# Los campos vacios no pisan nada: la escena conserva sus textos.
	var untouched := SHUTDOWN.instantiate() as WindowPanel3D
	untouched.variant_config = {"title": "", "message": "", "size": null}
	root.add_child(untouched)
	await _wait_frames(2)
	var kept := untouched.content.find_child("Title", true, false) as Label
	if kept == null or kept.text != "Salir":
		_fail("An empty variant field should keep the scene text.")
		untouched.free()
		return false
	untouched.free()
	return true


## Un tamaño fuera de rango se acota en vez de generar una ventana imposible.
func _check_variant_size_clamps() -> bool:
	var window := SHUTDOWN.instantiate() as WindowPanel3D
	window.variant_config = {"size": {"width": 10, "height": 9999}}
	root.add_child(window)
	await _wait_frames(2)
	var clamped := window.sub_viewport.size
	if clamped.x != WindowPanel3D.VARIANT_MIN_SIZE.x or clamped.y != WindowPanel3D.VARIANT_MAX_SIZE.y:
		_fail("An out-of-range variant size should clamp, got %s." % str(clamped))
		window.free()
		return false
	window.free()
	return true


## La variante es estetica: una descarga con textos propios sigue siendo una
## descarga, con su barra y su script de familia.
func _check_family_behaviour_survives() -> bool:
	var window := DOWNLOAD.instantiate() as DownloadWindow
	window.download_seconds = 60.0
	window.variant_config = {"title": "Bajando parche", "message": "parche_critico.exe"}
	root.add_child(window)
	await _wait_frames(3)
	if not window is DownloadWindow:
		_fail("A custom variant should keep its family script.")
		window.free()
		return false
	if window.content.find_child("Progress", true, false) == null:
		_fail("A custom download should keep its progress bar.")
		window.free()
		return false
	var title := window.content.find_child("Title", true, false) as Label
	if title == null or title.text != "Bajando parche":
		_fail("The variant title should apply on a download too.")
		window.free()
		return false
	if window.find_hit_body(DownloadWindow.CANCEL_ZONE) == null:
		_fail("A custom download should still offer its cancel control.")
		window.free()
		return false
	window.free()
	return true


## La skin re-viste el chrome sin tocar el comportamiento: una ventana XP puede
## verse Retro 97 y viceversa, y las zonas se generan igual.
func _check_skin_reskins_chrome() -> bool:
	# XP -> retro: el tema cambia y el cuerpo pasa a ser el marco retro.
	var retro_theme := preload("res://resources/themes/retro_theme.tres")
	var xp_theme := preload("res://resources/themes/xp_theme.tres")
	var window := SHUTDOWN.instantiate() as WindowPanel3D
	window.variant_config = {"skin": "retro", "title": "Banco Central"}
	root.add_child(window)
	await _wait_frames(3)
	if window.content.theme != retro_theme:
		_fail("A retro-skinned window should wear the retro theme.")
		window.free()
		return false
	var body := window.content.get_node_or_null("Body") as NinePatchRect
	if body == null or body.texture != WindowSkin.SKINS["retro"]["body_texture"]:
		_fail("A retro-skinned window should wear the retro frame.")
		window.free()
		return false
	if window.get_hit_bodies().is_empty():
		_fail("A reskinned window should still build its hit zones.")
		window.free()
		return false
	window.free()

	# Retro -> XP: la escena retro no trae barra propia, asi que se crea.
	var download := DOWNLOAD.instantiate() as DownloadWindow
	download.download_seconds = 60.0
	download.variant_config = {"skin": "xp"}
	root.add_child(download)
	await _wait_frames(3)
	if download.content.theme != xp_theme:
		_fail("An XP-skinned download should wear the XP theme.")
		download.free()
		return false
	var bar := download.content.get_node_or_null("SkinTitleBar") as NinePatchRect
	if bar == null or bar.texture != WindowSkin.SKINS["xp"]["titlebar_texture"]:
		_fail("An XP-skinned retro window should get an XP title bar.")
		download.free()
		return false
	if download.content.find_child("Progress", true, false) == null:
		_fail("Reskinning should not touch the family layout.")
		download.free()
		return false
	if download.find_hit_body(DownloadWindow.CANCEL_ZONE) == null:
		_fail("A reskinned download should still offer its cancel control.")
		download.free()
		return false
	download.free()

	# Una skin desconocida avisa y deja la de la escena.
	var kept := SHUTDOWN.instantiate() as WindowPanel3D
	kept.variant_config = {"skin": "vista"}
	root.add_child(kept)
	await _wait_frames(2)
	if kept.content.theme != xp_theme:
		_fail("An unknown skin should keep the scene skin.")
		kept.free()
		return false
	kept.free()
	return true


## Un bloque que declara el diseño spawnea ventanas vestidas con sus variantes.
func _check_block_spawns_design() -> bool:
	var block := BLOCK.instantiate() as TargetBlock3D
	block.block_size = Vector2(10.0, 5.0)
	var types := PackedStringArray()
	for _index in 4:
		types.append("custom:%s" % SEED_SLUG)
	block.layers.assign([types])
	root.add_child(block)
	await _wait_frames(4)
	if block.spawn_volume.active_targets.is_empty():
		_fail("The block should spawn the custom layer.")
		block.queue_free()
		return false
	for target in block.spawn_volume.active_targets:
		var window := target as WindowPanel3D
		if window == null:
			_fail("Every spawned target should be a window.")
			block.queue_free()
			return false
		var title := window.content.find_child("Title", true, false) as Label
		if title == null or not SEED_TITLES.has(title.text):
			_fail("Every window of the design should wear one of its variants, got '%s'." % (title.text if title != null else "<null>"))
			block.queue_free()
			return false
	block.queue_free()
	# El bloque muere en cola: un frame mas y no queda nada filtrado al salir.
	await _wait_frames(1)
	return true


func _wait_frames(count: int) -> void:
	for _frame in count:
		await physics_frame
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
